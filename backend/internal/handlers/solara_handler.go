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

	params := c.Request.URL.Query()
	params.Del("url")
	targetURL := musicAPIBase + "?" + params.Encode()
	h.proxyRequest(c, targetURL, nil)
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

// DiscoverLeaderboardList 获取排行榜列表（网易云官方API）
// GET /api/discover/leaderboard
func (h *SolaraHandler) DiscoverLeaderboardList(c *gin.Context) {
	if !h.isAuthed(c) {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false})
		return
	}
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

// DiscoverLeaderboardDetail 获取排行榜详情（网易云官方API）
// GET /api/discover/leaderboard/:id
func (h *SolaraHandler) DiscoverLeaderboardDetail(c *gin.Context) {
	if !h.isAuthed(c) {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false})
		return
	}
	id := c.Param("id")
	limitStr := c.DefaultQuery("limit", "30")
	limit := 30
	fmt.Sscanf(limitStr, "%d", &limit)

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

// DiscoverSongList 获取推荐歌单列表（网易云官方API）
// GET /api/discover/songlist
func (h *SolaraHandler) DiscoverSongList(c *gin.Context) {
	if !h.isAuthed(c) {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false})
		return
	}
	// 使用网易云精品歌单接口
	apiURL := "https://music.163.com/api/playlist/list?cat=%E5%85%A8%E9%83%A8&order=hot&offset=0&total=true&limit=30"
	tag := c.DefaultQuery("tag", "")
	if tag != "" {
		apiURL = fmt.Sprintf("https://music.163.com/api/playlist/list?cat=%s&order=hot&offset=0&total=true&limit=30", url.QueryEscape(tag))
	}
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

// DiscoverSongListDetail 获取歌单详情（网易云官方API）
// GET /api/discover/songlist/:id
func (h *SolaraHandler) DiscoverSongListDetail(c *gin.Context) {
	if !h.isAuthed(c) {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false})
		return
	}
	id := c.Param("id")
	limitStr := c.DefaultQuery("limit", "30")
	limit := 30
	fmt.Sscanf(limitStr, "%d", &limit)

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
