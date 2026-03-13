package handlers

type Handlers struct {
	Task    TaskHandler
	User    UserHandler
	Health  HealthHandler
	Captcha CaptchaHandler
	Solara  *SolaraHandler
}
