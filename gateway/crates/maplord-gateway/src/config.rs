/// Application configuration loaded from environment variables.
#[derive(Clone)]
pub struct AppConfig {
    pub secret_key: String,
    pub redis_host: String,
    pub redis_port: u16,
    pub redis_game_db: u8,
    pub django_internal_url: String,
    pub internal_secret: String,
    pub gateway_port: u16,
}

impl AppConfig {
    pub fn from_env() -> Self {
        Self {
            secret_key: std::env::var("SECRET_KEY")
                .unwrap_or_else(|_| "django-insecure-dev-key-change-in-production".into()),
            redis_host: std::env::var("REDIS_HOST").unwrap_or_else(|_| "redis".into()),
            redis_port: std::env::var("REDIS_PORT")
                .unwrap_or_else(|_| "6379".into())
                .parse()
                .unwrap_or(6379),
            redis_game_db: std::env::var("REDIS_GAME_DB")
                .unwrap_or_else(|_| "1".into())
                .parse()
                .unwrap_or(1),
            django_internal_url: std::env::var("DJANGO_INTERNAL_URL")
                .unwrap_or_else(|_| "http://backend:8000".into()),
            internal_secret: std::env::var("INTERNAL_SECRET")
                .unwrap_or_else(|_| "dev-internal-secret".into()),
            gateway_port: std::env::var("GATEWAY_PORT")
                .unwrap_or_else(|_| "8080".into())
                .parse()
                .unwrap_or(8080),
        }
    }

    pub fn redis_url(&self) -> String {
        format!(
            "redis://{}:{}/{}",
            self.redis_host, self.redis_port, self.redis_game_db
        )
    }
}
