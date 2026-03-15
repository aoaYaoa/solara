package handlers

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"backend/internal/models"
	"backend/pkg/utils/jwt"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

const (
	maxAgeSec    = 48 * 60 * 60
	musicAPIBase = "https://music-api.gdstudio.xyz/api.php"
)

var favoriteKeys = map[string]bool{
	"favoriteSongs":        true,
	"currentFavoriteIndex": true,
	"favoritePlayMode":     true,
	"favoritePlaybackTime": true,
}

type SolaraHandler struct {
	db *gorm.DB
}

func NewSolaraHandler(db *gorm.DB) *SolaraHandler {
	return &SolaraHandler{db: db}
}

func (h *SolaraHandler) Login(c *gin.Context) {
	var body struct {
		Password string `json:"password"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		body.Password = ""
	}

	password := os.Getenv("APP_PASSWORD")
	if password == "" {
		c.JSON(http.StatusOK, gin.H{"success": true})
		return
	}

	if body.Password != password {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false})
		return
	}

	cookieVal := base64.StdEncoding.EncodeToString([]byte(password))
	secure := c.Request.TLS != nil || c.GetHeader("X-Forwarded-Proto") == "https"
	sameSite := "SameSite=Lax"
	parts := []string{
		fmt.Sprintf("auth=%s", cookieVal),
		fmt.Sprintf("Max-Age=%d", maxAgeSec),
		"Path=/",
		sameSite,
		"HttpOnly",
	}
	if secure {
		parts = append(parts, "Secure")
	}
	c.Header("Set-Cookie", strings.Join(parts, "; "))

	// 同时返回 JWT token 供移动端/Flutter使用
	token, err := jwt.GenerateToken("app_user", "app_user", "app", "", 48*time.Hour)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"success": true})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"token": token}})
}

func (h *SolaraHandler) isAuthed(c *gin.Context) bool {
	authorization := c.GetHeader("Authorization")
	if strings.HasPrefix(authorization, "Bearer ") {
		token := strings.TrimPrefix(authorization, "Bearer ")
		if _, err := jwt.ValidateToken(token, ""); err == nil {
			return true
		}
	}
	password := os.Getenv("APP_PASSWORD")
	if password == "" {
		return true
	}
	cookie, err := c.Cookie("auth")
	if err != nil {
		return false
	}
	expected := base64.StdEncoding.EncodeToString([]byte(password))
	return cookie == expected
}

func (h *SolaraHandler) Storage(c *gin.Context) {
	if !h.isAuthed(c) {
		c.Redirect(http.StatusFound, "/")
		return
	}

	switch c.Request.Method {
	case http.MethodGet:
		h.storageGet(c)
	case http.MethodPost:
		h.storagePost(c)
	case http.MethodDelete:
		h.storageDelete(c)
	default:
		c.Status(http.StatusMethodNotAllowed)
	}
}

func (h *SolaraHandler) storageGet(c *gin.Context) {
	if c.Query("status") == "1" {
		c.JSON(http.StatusOK, gin.H{"d1Available": true})
		return
	}

	keysParam := c.Query("keys")
	if keysParam != "" {
		keys := strings.Split(keysParam, ",")
		result := make(map[string]interface{}, len(keys))
		for _, k := range keys {
			k = strings.TrimSpace(k)
			var val *string
			if favoriteKeys[k] {
				var row models.FavoritesStore
				if err := h.db.First(&row, "key = ?", k).Error; err == nil {
					v := row.Value
					val = &v
				}
			} else {
				var row models.PlaybackStore
				if err := h.db.First(&row, "key = ?", k).Error; err == nil {
					v := row.Value
					val = &v
				}
			}
			if val != nil {
				result[k] = *val
			} else {
				result[k] = nil
			}
		}
		c.JSON(http.StatusOK, gin.H{"d1Available": true, "data": result})
		return
	}

	result := make(map[string]string)
	var playback []models.PlaybackStore
	h.db.Find(&playback)
	for _, r := range playback {
		result[r.Key] = r.Value
	}
	var favorites []models.FavoritesStore
	h.db.Find(&favorites)
	for _, r := range favorites {
		result[r.Key] = r.Value
	}
	c.JSON(http.StatusOK, gin.H{"d1Available": true, "data": result})
}

func (h *SolaraHandler) storagePost(c *gin.Context) {
	var body struct {
		Data map[string]interface{} `json:"data"`
	}
	if err := c.ShouldBindJSON(&body); err != nil || body.Data == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid body"})
		return
	}
	for k, rawVal := range body.Data {
		var v string
		switch val := rawVal.(type) {
		case string:
			v = val
		default:
			b, err := json.Marshal(val)
			if err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": "invalid value for key " + k})
				return
			}
			v = string(b)
		}
		if favoriteKeys[k] {
			h.db.Clauses(clause.OnConflict{UpdateAll: true}).Create(&models.FavoritesStore{Key: k, Value: v, UpdatedAt: time.Now()})
		} else {
			h.db.Clauses(clause.OnConflict{UpdateAll: true}).Create(&models.PlaybackStore{Key: k, Value: v, UpdatedAt: time.Now()})
		}
	}
	c.JSON(http.StatusOK, gin.H{"d1Available": true, "success": true})
}

func (h *SolaraHandler) storageDelete(c *gin.Context) {
	var body struct {
		Keys []string `json:"keys"`
	}
	if err := c.ShouldBindJSON(&body); err != nil || len(body.Keys) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid body"})
		return
	}
	for _, k := range body.Keys {
		if favoriteKeys[k] {
			h.db.Delete(&models.FavoritesStore{}, "key = ?", k)
		} else {
			h.db.Delete(&models.PlaybackStore{}, "key = ?", k)
		}
	}
	c.JSON(http.StatusOK, gin.H{"success": true})
}

func (h *SolaraHandler) Proxy(c *gin.Context) {
	if !h.isAuthed(c) {
		c.Status(http.StatusUnauthorized)
		return
	}

	targetParam := c.Query("url")
	if targetParam != "" {
		h.proxyKuwoAudio(c, targetParam)
		return
	}

	source := c.Query("source")
	types := c.Query("types")

	switch source {
	case "bilibili":
		switch types {
		case "search":
			page := 1
			count := 20
			fmt.Sscanf(c.DefaultQuery("pages", "1"), "%d", &page)
			fmt.Sscanf(c.DefaultQuery("count", "20"), "%d", &count)
			results, err := h.BilibiliSearch(c.Query("name"), page, count)
			if err != nil {
				c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
				return
			}
			c.JSON(http.StatusOK, results)
		case "url":
			bvid := c.Query("id")
			audioURL, err := h.BilibiliPlayUrl(bvid)
			if err != nil {
				c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
				return
			}
			// 返回JSON让前端直接播放（B站音频URL含鉴权参数，前端用时效性URL即可）
			c.JSON(http.StatusOK, gin.H{"url": audioURL})
		case "mv":
			bvid := c.Query("id")
			// MV 用视频流，目前复用音频 URL（前端 video_player 可播放）
			audioURL, err := h.BilibiliPlayUrl(bvid)
			if err != nil {
				c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
				return
			}
			c.JSON(http.StatusOK, gin.H{"url": audioURL})
		default:
			c.JSON(http.StatusBadRequest, gin.H{"error": "unsupported types for bilibili"})
		}
	case "youtube":
		switch types {
		case "search":
			count := 20
			fmt.Sscanf(c.DefaultQuery("count", "20"), "%d", &count)
			results, err := youtubeSearch(c.Query("name"), count)
			if err != nil {
				c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
				return
			}
			c.JSON(http.StatusOK, results)
		case "url", "mv":
			videoId := c.Query("id")
			audioURL, err := youtubeGetAudioUrl(videoId)
			if err != nil {
				c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
				return
			}
			c.JSON(http.StatusOK, gin.H{"url": audioURL})
		default:
			c.JSON(http.StatusBadRequest, gin.H{"error": "unsupported types for youtube"})
		}
	case "jamendo":
		switch types {
		case "search":
			count := 20
			fmt.Sscanf(c.DefaultQuery("count", "20"), "%d", &count)
			results, err := jamendoSearch(c.Query("name"), count)
			if err != nil {
				c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
				return
			}
			c.JSON(http.StatusOK, results)
		case "url":
			// Jamendo url_id 直接是音频URL，前端直接播放，此处仅透传
			audioURL := c.Query("id")
			if strings.HasPrefix(audioURL, "http") {
				c.JSON(http.StatusOK, gin.H{"url": audioURL})
			} else {
				c.JSON(http.StatusBadRequest, gin.H{"error": "invalid jamendo url_id"})
			}
		default:
			c.JSON(http.StatusBadRequest, gin.H{"error": "unsupported types for jamendo"})
		}
	default:
		// 国内四源：透传到 music-api
		params := c.Request.URL.Query()
		params.Del("url")
		targetURL := musicAPIBase + "?" + params.Encode()
		h.proxyRequest(c, targetURL, nil)
	}
}

// ImgProxy 代理网易云图片，加上 Referer 头绕过防盗链
func (h *SolaraHandler) ImgProxy(c *gin.Context) {
	targetURL := c.Query("url")
	if targetURL == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing url"})
		return
	}
	client := &http.Client{Timeout: 10 * time.Second}
	req, err := http.NewRequestWithContext(c.Request.Context(), "GET", targetURL, nil)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid url"})
		return
	}
	req.Header.Set("Referer", "https://music.163.com/")
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
	resp, err := client.Do(req)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
		return
	}
	defer resp.Body.Close()
	c.Header("Content-Type", resp.Header.Get("Content-Type"))
	c.Header("Cache-Control", "public, max-age=86400")
	c.Header("Access-Control-Allow-Origin", "*")
	c.Status(resp.StatusCode)
	io.Copy(c.Writer, resp.Body)
}

// neteaseGetSongUrl 获取网易云歌曲播放URL
func (h *SolaraHandler) neteaseGetSongUrl(c *gin.Context) {
	id := c.Query("id")
	br := c.DefaultQuery("br", "320000")
	// br 参数：前端传 "128"/"320"/"flac"，网易云需要 bit rate 数字
	brMap := map[string]string{
		"128":  "128000",
		"320":  "320000",
		"flac": "999000",
	}
	if mapped, ok := brMap[br]; ok {
		br = mapped
	}
	apiURL := fmt.Sprintf("https://music.163.com/api/song/enhance/player/url?id=%s&br=%s", url.QueryEscape(id), br)
	data, err := fetchNetease(apiURL)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
		return
	}
	dataArr, _ := data["data"].([]interface{})
	if len(dataArr) == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "no url found"})
		return
	}
	first, _ := dataArr[0].(map[string]interface{})
	songURL, _ := first["url"].(string)
	if songURL == "" {
		c.JSON(http.StatusNotFound, gin.H{"error": "song url is empty (may require VIP or not available)"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"url": songURL})
}

func (h *SolaraHandler) proxyKuwoAudio(c *gin.Context, targetURL string) {
	parsed, err := url.Parse(targetURL)
	if err != nil || !strings.HasSuffix(parsed.Hostname(), "kuwo.cn") {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid target"})
		return
	}
	parsed.Scheme = "http"
	extraHeaders := map[string]string{
		"Referer": "https://www.kuwo.cn/",
	}
	h.proxyRequest(c, parsed.String(), extraHeaders)
}

func (h *SolaraHandler) proxyRequest(c *gin.Context, targetURL string, extraHeaders map[string]string) {
	req, err := http.NewRequestWithContext(c.Request.Context(), c.Request.Method, targetURL, nil)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create request"})
		return
	}
	req.Header.Set("User-Agent", c.GetHeader("User-Agent"))
	if rangeH := c.GetHeader("Range"); rangeH != "" {
		req.Header.Set("Range", rangeH)
	}
	for k, v := range extraHeaders {
		req.Header.Set(k, v)
	}

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "upstream request failed"})
		return
	}
	defer resp.Body.Close()

	safeHeaders := []string{"Content-Type", "Cache-Control", "Accept-Ranges", "Content-Length", "Content-Range", "ETag", "Last-Modified", "Expires"}
	for _, h := range safeHeaders {
		if v := resp.Header.Get(h); v != "" {
			c.Header(h, v)
		}
	}
	c.Header("Access-Control-Allow-Origin", "*")
	c.Status(resp.StatusCode)
	io.Copy(c.Writer, resp.Body)
}

// jsonIDToString 将 JSON 解析出的数字 ID 转为整数字符串，避免 float64 精度损失
func jsonIDToString(v interface{}) string {
	switch val := v.(type) {
	case json.Number:
		return val.String()
	case float64:
		return fmt.Sprintf("%d", int64(val))
	case string:
		return val
	default:
		return fmt.Sprintf("%v", v)
	}
}

// neteaseHeaders 返回请求网易云 API 所需的请求头
func neteaseHeaders() map[string]string {
	return map[string]string{
		"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
		"Referer":    "https://music.163.com/",
	}
}

// fetchNetease 发起网易云 API 请求并返回解析后的 JSON
func fetchNetease(apiURL string) (map[string]interface{}, error) {
	client := &http.Client{Timeout: 10 * time.Second}
	req, err := http.NewRequest("GET", apiURL, nil)
	if err != nil {
		return nil, err
	}
	for k, v := range neteaseHeaders() {
		req.Header.Set(k, v)
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	var result map[string]interface{}
	dec := json.NewDecoder(resp.Body)
	dec.UseNumber() // 避免大整数精度损失
	if err := dec.Decode(&result); err != nil {
		return nil, err
	}
	return result, nil
}

// DiscoverLeaderboardList 获取排行榜列表
// GET /api/discover/leaderboard?source=netease|bilibili|youtube|jamendo
func (h *SolaraHandler) DiscoverLeaderboardList(c *gin.Context) {
	if !h.isAuthed(c) {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false})
		return
	}
	source := c.DefaultQuery("source", "netease")
	switch source {
	case "bilibili":
		result, err := bilibiliLeaderboardList()
		if err != nil {
			c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, result)
	case "youtube":
		result, err := youtubeLeaderboardList()
		if err != nil {
			c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, result)
	case "jamendo":
		result, err := jamendoLeaderboardList()
		if err != nil {
			c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, result)
	default: // netease and others
		data, err := fetchNetease("https://music.163.com/api/toplist")
		if err != nil {
			c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
			return
		}
		list, _ := data["list"].([]interface{})
		result := make([]map[string]interface{}, 0, len(list))
		for _, item := range list {
			m, ok := item.(map[string]interface{})
			if !ok {
				continue
			}
			result = append(result, map[string]interface{}{
				"id":              jsonIDToString(m["id"]),
				"name":            m["name"],
				"coverUrl":        m["coverImgUrl"],
				"updateFrequency": m["updateFrequency"],
				"source":          "netease",
			})
		}
		c.JSON(http.StatusOK, result)
	}
}

// DiscoverLeaderboardDetail 获取排行榜详情
// GET /api/discover/leaderboard/:id?source=...
func (h *SolaraHandler) DiscoverLeaderboardDetail(c *gin.Context) {
	if !h.isAuthed(c) {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false})
		return
	}
	source := c.DefaultQuery("source", "netease")
	limitStr := c.DefaultQuery("limit", "30")
	limit := 30
	fmt.Sscanf(limitStr, "%d", &limit)

	switch source {
	case "bilibili":
		result, err := bilibiliLeaderboardDetail(limit)
		if err != nil {
			c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, result)
		return
	case "youtube":
		result, err := youtubeLeaderboardDetail(limit)
		if err != nil {
			c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, result)
		return
	case "jamendo":
		result, err := jamendoLeaderboardDetail(limit)
		if err != nil {
			c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, result)
		return
	}

	id := c.Param("id")

	apiURL := fmt.Sprintf("https://music.163.com/api/v3/playlist/detail?id=%s&n=%d", url.QueryEscape(id), limit)
	data, err := fetchNetease(apiURL)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
		return
	}
	playlist, _ := data["playlist"].(map[string]interface{})
	if playlist == nil {
		c.JSON(http.StatusOK, []interface{}{})
		return
	}
	tracks, _ := playlist["tracks"].([]interface{})
	result := make([]map[string]interface{}, 0, len(tracks))
	for _, item := range tracks {
		t, ok := item.(map[string]interface{})
		if !ok {
			continue
		}
		artists := ""
		if ar, ok := t["ar"].([]interface{}); ok && len(ar) > 0 {
			if a, ok := ar[0].(map[string]interface{}); ok {
				artists, _ = a["name"].(string)
			}
		}
		al, _ := t["al"].(map[string]interface{})
		picId := ""
		picUrl := ""
		if al != nil {
			picUrl, _ = al["picUrl"].(string)
			picId = jsonIDToString(al["pic"])
			if picId == "0" || picId == "" {
				picId = jsonIDToString(al["id"])
			}
		}
		songID := jsonIDToString(t["id"])
		albumName := ""
		if al != nil {
			albumName, _ = al["name"].(string)
		}
		result = append(result, map[string]interface{}{
			"id":       songID,
			"name":     t["name"],
			"artist":   artists,
			"album":    albumName,
			"pic_id":   picId,
			"pic_url":  picUrl,
			"url_id":   songID,
			"lyric_id": songID,
			"source":   "netease",
		})
	}
	c.JSON(http.StatusOK, result)
}

// DiscoverSongList 获取推荐歌单列表
// GET /api/discover/songlist?source=netease|bilibili|youtube|jamendo
func (h *SolaraHandler) DiscoverSongList(c *gin.Context) {
	if !h.isAuthed(c) {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false})
		return
	}
	source := c.DefaultQuery("source", "netease")
	switch source {
	case "bilibili":
		result, err := bilibiliSongList()
		if err != nil {
			c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, result)
	case "youtube", "jamendo":
		// YouTube/Jamendo 无歌单概念，返回空
		c.JSON(http.StatusOK, []interface{}{})
	default: // netease
		limitStr := c.DefaultQuery("limit", "30")
		limit := 30
		fmt.Sscanf(limitStr, "%d", &limit)
		pageStr := c.DefaultQuery("page", "1")
		page := 1
		fmt.Sscanf(pageStr, "%d", &page)
		offset := (page - 1) * limit
		tag := c.DefaultQuery("tag", "")
		cat := "%E5%85%A8%E9%83%A8"
		if tag != "" {
			cat = url.QueryEscape(tag)
		}
		apiURL := fmt.Sprintf("https://music.163.com/api/playlist/list?cat=%s&order=hot&offset=%d&total=true&limit=%d", cat, offset, limit)
		data, err := fetchNetease(apiURL)
		if err != nil {
			c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
			return
		}
		playlists, _ := data["playlists"].([]interface{})
		result := make([]map[string]interface{}, 0, len(playlists))
		for _, item := range playlists {
			m, ok := item.(map[string]interface{})
			if !ok {
				continue
			}
			creator := ""
			if cr, ok := m["creator"].(map[string]interface{}); ok {
				creator, _ = cr["nickname"].(string)
			}
			result = append(result, map[string]interface{}{
				"id":          jsonIDToString(m["id"]),
				"name":        m["name"],
				"author":      creator,
				"coverUrl":    m["coverImgUrl"],
				"playCount":   fmt.Sprintf("%v", m["playCount"]),
				"description": m["description"],
				"source":      "netease",
			})
		}
		c.JSON(http.StatusOK, result)
	}
}

// DiscoverSongListDetail 获取歌单详情
// GET /api/discover/songlist/:id?source=...
func (h *SolaraHandler) DiscoverSongListDetail(c *gin.Context) {
	if !h.isAuthed(c) {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false})
		return
	}
	source := c.DefaultQuery("source", "netease")
	limitStr := c.DefaultQuery("limit", "30")
	limit := 30
	fmt.Sscanf(limitStr, "%d", &limit)

	switch source {
	case "bilibili":
		result, err := bilibiliLeaderboardDetail(limit)
		if err != nil {
			c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, result)
		return
	case "youtube", "jamendo":
		c.JSON(http.StatusOK, []interface{}{})
		return
	}

	id := c.Param("id")

	apiURL := fmt.Sprintf("https://music.163.com/api/v3/playlist/detail?id=%s&n=%d", url.QueryEscape(id), limit)
	data, err := fetchNetease(apiURL)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
		return
	}
	playlist, _ := data["playlist"].(map[string]interface{})
	if playlist == nil {
		c.JSON(http.StatusOK, []interface{}{})
		return
	}
	tracks, _ := playlist["tracks"].([]interface{})
	result := make([]map[string]interface{}, 0, len(tracks))
	for _, item := range tracks {
		t, ok := item.(map[string]interface{})
		if !ok {
			continue
		}
		artists := ""
		if ar, ok := t["ar"].([]interface{}); ok && len(ar) > 0 {
			if a, ok := ar[0].(map[string]interface{}); ok {
				artists, _ = a["name"].(string)
			}
		}
		al, _ := t["al"].(map[string]interface{})
		picId := ""
		picUrl := ""
		if al != nil {
			picUrl, _ = al["picUrl"].(string)
			picId = jsonIDToString(al["pic"])
			if picId == "0" || picId == "" {
				picId = jsonIDToString(al["id"])
			}
		}
		songID := jsonIDToString(t["id"])
		albumName := ""
		if al != nil {
			albumName, _ = al["name"].(string)
		}
		result = append(result, map[string]interface{}{
			"id":       songID,
			"name":     t["name"],
			"artist":   artists,
			"album":    albumName,
			"pic_id":   picId,
			"pic_url":  picUrl,
			"url_id":   songID,
			"lyric_id": songID,
			"source":   "netease",
		})
	}
	c.JSON(http.StatusOK, result)
}

// ─────────────────────────────────────────────────────────────────────────────
// Bilibili 音源
// ─────────────────────────────────────────────────────────────────────────────

func bilibiliHeaders() map[string]string {
	return map[string]string{
		"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
		"Referer":    "https://www.bilibili.com/",
	}
}

func fetchBilibili(apiURL string) (map[string]interface{}, error) {
	client := &http.Client{Timeout: 10 * time.Second}
	req, err := http.NewRequest("GET", apiURL, nil)
	if err != nil {
		return nil, err
	}
	for k, v := range bilibiliHeaders() {
		req.Header.Set(k, v)
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	var result map[string]interface{}
	dec := json.NewDecoder(resp.Body)
	dec.UseNumber()
	if err := dec.Decode(&result); err != nil {
		return nil, err
	}
	return result, nil
}

// BilibiliSearch 搜索B站音乐视频
func (h *SolaraHandler) BilibiliSearch(keyword string, page, count int) ([]map[string]interface{}, error) {
	apiURL := fmt.Sprintf(
		"https://api.bilibili.com/x/web-interface/search/type?search_type=video&keyword=%s&tids=3&page=%d&page_size=%d",
		url.QueryEscape(keyword), page, count,
	)
	data, err := fetchBilibili(apiURL)
	if err != nil {
		return nil, err
	}
	dataMap, _ := data["data"].(map[string]interface{})
	if dataMap == nil {
		return []map[string]interface{}{}, nil
	}
	result2, _ := dataMap["result"].([]interface{})
	result := make([]map[string]interface{}, 0, len(result2))
	for _, item := range result2 {
		m, ok := item.(map[string]interface{})
		if !ok {
			continue
		}
		bvid, _ := m["bvid"].(string)
		if bvid == "" {
			continue
		}
		title, _ := m["title"].(string)
		// 去除 HTML 标签
		title = strings.ReplaceAll(title, "<em class=\"keyword\">", "")
		title = strings.ReplaceAll(title, "</em>", "")
		author, _ := m["author"].(string)
		pic, _ := m["pic"].(string)
		if !strings.HasPrefix(pic, "http") {
			pic = "https:" + pic
		}
		result = append(result, map[string]interface{}{
			"id":       bvid,
			"name":     title,
			"artist":   author,
			"album":    "Bilibili",
			"pic_id":   "",
			"pic_url":  pic,
			"url_id":   bvid,
			"lyric_id": "",
			"source":   "bilibili",
		})
	}
	return result, nil
}

// BilibiliPlayUrl 获取B站视频音频流URL
func (h *SolaraHandler) BilibiliPlayUrl(bvid string) (string, error) {
	// 1. 获取 cid
	pageURL := fmt.Sprintf("https://api.bilibili.com/x/player/pagelist?bvid=%s", url.QueryEscape(bvid))
	pageData, err := fetchBilibili(pageURL)
	if err != nil {
		return "", err
	}
	pages, _ := pageData["data"].([]interface{})
	if len(pages) == 0 {
		return "", fmt.Errorf("no pages found for bvid %s", bvid)
	}
	firstPage, _ := pages[0].(map[string]interface{})
	cid := jsonIDToString(firstPage["cid"])

	// 2. 获取播放 URL（fnval=16 = dash格式）
	playURL := fmt.Sprintf(
		"https://api.bilibili.com/x/player/playurl?bvid=%s&cid=%s&fnval=16&qn=64",
		url.QueryEscape(bvid), url.QueryEscape(cid),
	)
	playData, err := fetchBilibili(playURL)
	if err != nil {
		return "", err
	}
	dataMap, _ := playData["data"].(map[string]interface{})
	if dataMap == nil {
		return "", fmt.Errorf("no data in playurl response")
	}

	// 优先取 dash audio
	if dash, ok := dataMap["dash"].(map[string]interface{}); ok {
		if audioList, ok := dash["audio"].([]interface{}); ok && len(audioList) > 0 {
			// 取第一个（最高码率）
			if audioItem, ok := audioList[0].(map[string]interface{}); ok {
				if baseUrl, ok := audioItem["baseUrl"].(string); ok && baseUrl != "" {
					return baseUrl, nil
				}
				if baseUrl, ok := audioItem["base_url"].(string); ok && baseUrl != "" {
					return baseUrl, nil
				}
			}
		}
	}

	// fallback: durl
	if durls, ok := dataMap["durl"].([]interface{}); ok && len(durls) > 0 {
		if d, ok := durls[0].(map[string]interface{}); ok {
			if u, ok := d["url"].(string); ok && u != "" {
				return u, nil
			}
		}
	}
	return "", fmt.Errorf("no audio url found")
}

func bilibiliLeaderboardList() ([]map[string]interface{}, error) {
	// B站音乐区周榜 rid=3
	apiURL := "https://api.bilibili.com/x/web-interface/ranking/v2?rid=3&type=all"
	data, err := fetchBilibili(apiURL)
	if err != nil {
		return nil, err
	}
	dataMap, _ := data["data"].(map[string]interface{})
	if dataMap == nil {
		return []map[string]interface{}{}, nil
	}
	list, _ := dataMap["list"].([]interface{})
	// 只返回一个「音乐区周榜」条目，内容是视频列表
	result := []map[string]interface{}{
		{
			"id":              "bilibili_music_ranking",
			"name":            "音乐区周榜",
			"coverUrl":        "",
			"updateFrequency": "每周更新",
			"source":          "bilibili",
			"_list":           list, // 内嵌，供 detail 接口使用
		},
	}
	if len(list) > 0 {
		if first, ok := list[0].(map[string]interface{}); ok {
			if pic, ok := first["pic"].(string); ok && pic != "" {
				if !strings.HasPrefix(pic, "http") {
					pic = "https:" + pic
				}
				result[0]["coverUrl"] = pic
			}
		}
	}
	return result, nil
}

func bilibiliSongList() ([]map[string]interface{}, error) {
	// 用音乐区排行榜视频列表作为「歌单」
	apiURL := "https://api.bilibili.com/x/web-interface/ranking/v2?rid=3&type=all"
	data, err := fetchBilibili(apiURL)
	if err != nil {
		return nil, err
	}
	dataMap, _ := data["data"].(map[string]interface{})
	if dataMap == nil {
		return []map[string]interface{}{}, nil
	}
	return []map[string]interface{}{
		{
			"id":          "bilibili_music_ranking",
			"name":        "音乐区周榜",
			"author":      "Bilibili",
			"coverUrl":    "",
			"playCount":   "",
			"description": "B站音乐区本周最热视频",
			"source":      "bilibili",
		},
	}, nil
}

func bilibiliLeaderboardDetail(limit int) ([]map[string]interface{}, error) {
	apiURL := "https://api.bilibili.com/x/web-interface/ranking/v2?rid=3&type=all"
	data, err := fetchBilibili(apiURL)
	if err != nil {
		return nil, err
	}
	dataMap, _ := data["data"].(map[string]interface{})
	if dataMap == nil {
		return []map[string]interface{}{}, nil
	}
	list, _ := dataMap["list"].([]interface{})
	result := make([]map[string]interface{}, 0)
	for i, item := range list {
		if i >= limit {
			break
		}
		m, ok := item.(map[string]interface{})
		if !ok {
			continue
		}
		bvid, _ := m["bvid"].(string)
		title, _ := m["title"].(string)
		owner, _ := m["owner"].(map[string]interface{})
		author := ""
		if owner != nil {
			author, _ = owner["name"].(string)
		}
		pic, _ := m["pic"].(string)
		if !strings.HasPrefix(pic, "http") {
			pic = "https:" + pic
		}
		result = append(result, map[string]interface{}{
			"id":       bvid,
			"name":     title,
			"artist":   author,
			"album":    "Bilibili音乐区",
			"pic_id":   "",
			"pic_url":  pic,
			"url_id":   bvid,
			"lyric_id": "",
			"source":   "bilibili",
		})
	}
	return result, nil
}

// ─────────────────────────────────────────────────────────────────────────────
// Jamendo 音源
// ─────────────────────────────────────────────────────────────────────────────

func jamendoClientID() string {
	return os.Getenv("JAMENDO_CLIENT_ID")
}

func fetchJamendo(apiURL string) (map[string]interface{}, error) {
	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Get(apiURL)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	return result, nil
}

func jamendoSearch(keyword string, limit int) ([]map[string]interface{}, error) {
	cid := jamendoClientID()
	if cid == "" {
		return nil, fmt.Errorf("JAMENDO_CLIENT_ID not configured")
	}
	apiURL := fmt.Sprintf(
		"https://api.jamendo.com/v3.0/tracks?client_id=%s&namesearch=%s&format=json&limit=%d&include=musicinfo",
		cid, url.QueryEscape(keyword), limit,
	)
	return jamendoParseTracks(apiURL)
}

func jamendoLeaderboardList() ([]map[string]interface{}, error) {
	cid := jamendoClientID()
	coverUrl := ""
	if cid != "" {
		// 取第一首热门曲目的封面作为列表封面
		apiURL := fmt.Sprintf(
			"https://api.jamendo.com/v3.0/tracks?client_id=%s&order=popularity_total&format=json&limit=1",
			cid,
		)
		if data, err := fetchJamendo(apiURL); err == nil {
			if results, ok := data["results"].([]interface{}); ok && len(results) > 0 {
				if m, ok := results[0].(map[string]interface{}); ok {
					coverUrl, _ = m["image"].(string)
				}
			}
		}
	}
	return []map[string]interface{}{
		{
			"id":              "jamendo_popular",
			"name":            "热门音乐",
			"coverUrl":        coverUrl,
			"updateFrequency": "实时更新",
			"source":          "jamendo",
		},
	}, nil
}

func jamendoParseTracks(apiURL string) ([]map[string]interface{}, error) {
	data, err := fetchJamendo(apiURL)
	if err != nil {
		return nil, err
	}
	results, _ := data["results"].([]interface{})
	out := make([]map[string]interface{}, 0, len(results))
	for _, item := range results {
		m, ok := item.(map[string]interface{})
		if !ok {
			continue
		}
		id, _ := m["id"].(string)
		name, _ := m["name"].(string)
		artist, _ := m["artist_name"].(string)
		album, _ := m["album_name"].(string)
		audio, _ := m["audio"].(string)
		image, _ := m["image"].(string)
		out = append(out, map[string]interface{}{
			"id":       id,
			"name":     name,
			"artist":   artist,
			"album":    album,
			"pic_id":   "",
			"pic_url":  image,
			"url_id":   audio, // 直接是播放URL
			"lyric_id": "",
			"source":   "jamendo",
		})
	}
	return out, nil
}

func jamendoLeaderboardDetail(limit int) ([]map[string]interface{}, error) {
	cid := jamendoClientID()
	if cid == "" {
		return nil, fmt.Errorf("JAMENDO_CLIENT_ID not configured")
	}
	apiURL := fmt.Sprintf(
		"https://api.jamendo.com/v3.0/tracks?client_id=%s&order=popularity_total&format=json&limit=%d",
		cid, limit,
	)
	return jamendoParseTracks(apiURL)
}

// ─────────────────────────────────────────────────────────────────────────────
// YouTube Music 音源（InnerTube API）
// ─────────────────────────────────────────────────────────────────────────────

var youtubeInnertubeContext = map[string]interface{}{
	"client": map[string]interface{}{
		"clientName":    "WEB_REMIX",
		"clientVersion": "1.20240101.00.00",
		"hl":            "zh-CN",
	},
}

// iOS 客户端 context，用于获取未加密的播放 URL
var youtubeIOSContext = map[string]interface{}{
	"client": map[string]interface{}{
		"clientName":    "IOS",
		"clientVersion": "19.29.1",
		"deviceMake":    "Apple",
		"deviceModel":   "iPhone16,2",
		"osName":        "iPhone",
		"osVersion":     "17.5.1.21F90",
		"hl":            "zh-CN",
	},
}

func fetchYouTube(apiURL string, body map[string]interface{}) (map[string]interface{}, error) {
	body["context"] = youtubeInnertubeContext
	payload, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}
	client := &http.Client{Timeout: 15 * time.Second}
	req, err := http.NewRequest("POST", apiURL, strings.NewReader(string(payload)))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
	req.Header.Set("Origin", "https://music.youtube.com")
	req.Header.Set("Referer", "https://music.youtube.com/")
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	var result map[string]interface{}
	dec := json.NewDecoder(resp.Body)
	dec.UseNumber()
	if err := dec.Decode(&result); err != nil {
		return nil, err
	}
	return result, nil
}

func youtubeSearch(keyword string, limit int) ([]map[string]interface{}, error) {
	apiURL := "https://music.youtube.com/youtubei/v1/search?prettyPrint=false"
	data, err := fetchYouTube(apiURL, map[string]interface{}{"query": keyword})
	if err != nil {
		return nil, err
	}
	// 递归遍历找 musicResponsiveListItemRenderer
	result := make([]map[string]interface{}, 0)
	youtubeExtractSongs(data, &result, limit)
	return result, nil
}

func youtubeExtractSongs(node interface{}, result *[]map[string]interface{}, limit int) {
	if len(*result) >= limit {
		return
	}
	switch v := node.(type) {
	case map[string]interface{}:
		// musicResponsiveListItemRenderer 是搜索结果 item
		if renderer, ok := v["musicResponsiveListItemRenderer"].(map[string]interface{}); ok {
			if song := youtubeParseListItem(renderer); song != nil {
				*result = append(*result, song)
			}
			return
		}
		for _, val := range v {
			youtubeExtractSongs(val, result, limit)
		}
	case []interface{}:
		for _, item := range v {
			youtubeExtractSongs(item, result, limit)
		}
	}
}

func youtubeParseListItem(renderer map[string]interface{}) map[string]interface{} {
	// 提取 videoId
	videoId := ""
	if overlay, ok := renderer["overlay"].(map[string]interface{}); ok {
		if mtivor, ok := overlay["musicItemThumbnailOverlayRenderer"].(map[string]interface{}); ok {
			if content, ok := mtivor["content"].(map[string]interface{}); ok {
				if mptbr, ok := content["musicPlayButtonRenderer"].(map[string]interface{}); ok {
					if playNav, ok := mptbr["playNavigationEndpoint"].(map[string]interface{}); ok {
						if watchEndpoint, ok := playNav["watchEndpoint"].(map[string]interface{}); ok {
							videoId, _ = watchEndpoint["videoId"].(string)
						}
					}
				}
			}
		}
	}
	if videoId == "" {
		return nil
	}
	// 提取标题和副标题
	title := ""
	artist := ""
	if flexColumns, ok := renderer["flexColumns"].([]interface{}); ok {
		for i, col := range flexColumns {
			colMap, ok := col.(map[string]interface{})
			if !ok {
				continue
			}
			if mrlfc, ok := colMap["musicResponsiveListItemFlexColumnRenderer"].(map[string]interface{}); ok {
				if text, ok := mrlfc["text"].(map[string]interface{}); ok {
					if runs, ok := text["runs"].([]interface{}); ok && len(runs) > 0 {
						if run, ok := runs[0].(map[string]interface{}); ok {
							t, _ := run["text"].(string)
							if i == 0 {
								title = t
							} else if i == 1 && artist == "" {
								artist = t
							}
						}
					}
				}
			}
		}
	}
	if title == "" {
		return nil
	}
	picUrl := fmt.Sprintf("https://i.ytimg.com/vi/%s/hqdefault.jpg", videoId)
	return map[string]interface{}{
		"id":       videoId,
		"name":     title,
		"artist":   artist,
		"album":    "YouTube Music",
		"pic_id":   "",
		"pic_url":  picUrl,
		"url_id":   videoId,
		"lyric_id": "",
		"source":   "youtube",
	}
}

func youtubeGetAudioUrl(videoId string) (string, error) {
	// 使用 iOS 客户端获取未加密的音频 URL
	apiURL := "https://www.youtube.com/youtubei/v1/player?prettyPrint=false"
	body := map[string]interface{}{
		"videoId": videoId,
		"context": youtubeIOSContext,
	}
	payload, _ := json.Marshal(body)
	client := &http.Client{Timeout: 15 * time.Second}
	req, err := http.NewRequest("POST", apiURL, strings.NewReader(string(payload)))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X)")
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	var data map[string]interface{}
	dec := json.NewDecoder(resp.Body)
	dec.UseNumber()
	if err := dec.Decode(&data); err != nil {
		return "", err
	}
	if err != nil {
		return "", err
	}
	streaming, _ := data["streamingData"].(map[string]interface{})
	if streaming == nil {
		return "", fmt.Errorf("no streamingData")
	}
	// 优先 adaptiveFormats 中的音频流（无视频）
	if adaptive, ok := streaming["adaptiveFormats"].([]interface{}); ok {
		bestBitrate := 0
		bestURL := ""
		for _, item := range adaptive {
			m, ok := item.(map[string]interface{})
			if !ok {
				continue
			}
			mimeType, _ := m["mimeType"].(string)
			if !strings.HasPrefix(mimeType, "audio/") {
				continue
			}
			// 只取无签名的 url（有 signatureCipher 的需要解密）
			u, _ := m["url"].(string)
			if u == "" {
				continue
			}
			var br int
			if bitrateNum, ok := m["bitrate"].(json.Number); ok {
				fmt.Sscanf(bitrateNum.String(), "%d", &br)
			}
			if br > bestBitrate {
				bestBitrate = br
				bestURL = u
			}
		}
		if bestURL != "" {
			return bestURL, nil
		}
	}
	// fallback: formats
	if formats, ok := streaming["formats"].([]interface{}); ok && len(formats) > 0 {
		if m, ok := formats[0].(map[string]interface{}); ok {
			if u, ok := m["url"].(string); ok && u != "" {
				return u, nil
			}
		}
	}
	return "", fmt.Errorf("no unsigned audio url found (video may require signature decryption)")
}

func youtubeLeaderboardList() ([]map[string]interface{}, error) {
	return []map[string]interface{}{
		{
			"id":              "youtube_charts",
			"name":            "全球音乐排行",
			"coverUrl":        "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
			"updateFrequency": "每日更新",
			"source":          "youtube",
		},
	}, nil
}

func youtubeLeaderboardDetail(limit int) ([]map[string]interface{}, error) {
	// 用搜索热门歌曲作为排行榜内容
	return youtubeSearch("top hits music 2024", limit)
}