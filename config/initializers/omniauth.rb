Rails.application.config.middleware.use OmniAuth::Builder do
  provider :entra_id,
    client_id: ENV.fetch("ENTRA_CLIENT_ID", "not-configured"),
    client_secret: ENV.fetch("ENTRA_CLIENT_SECRET", "not-configured"),
    tenant_id: ENV.fetch("ENTRA_TENANT_ID", "common")
end

OmniAuth.config.on_failure = proc { |env|
  Auth::CallbacksController.action(:failure).call(env)
}

if Rails.env.production?
  %w[ENTRA_CLIENT_ID ENTRA_CLIENT_SECRET ENTRA_TENANT_ID].each do |key|
    raise "Missing required environment variable: #{key}" unless ENV[key].present?
  end
end
