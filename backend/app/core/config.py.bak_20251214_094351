from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    station_root: str = ""
    edit_mode_key: str = "1234"

    # runtime
    environment: str = "dev"
    cors_allow_origins: str = "*"

    # keys and integrations (stored in backend store, masked in reads)
    openai_api_key: str = ""
    github_token: str = ""
    github_repo: str = ""
    render_api_key: str = ""
    render_service_id: str = ""

    webhooks_url: str = ""
    tts_key: str = ""
    ocr_key: str = ""
    web_integration_key: str = ""
    whatsapp_key: str = ""
    email_smtp: str = ""

    # security
    require_edit_key_for_ops: bool = True
    max_body_kb: int = 512
    rate_limit_rpm: int = 120  # lightweight in-process limiter

    model_config = SettingsConfigDict(env_prefix="STATION_", extra="ignore")

settings = Settings()
