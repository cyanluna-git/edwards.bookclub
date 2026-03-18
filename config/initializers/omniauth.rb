Rails.application.config.middleware.use OmniAuth::Builder do
  provider :entra_id,
    client_id: ENV.fetch("ENTRA_CLIENT_ID", Rails.env.test? ? "test-client-id" : "not-configured"),
    client_secret: ENV.fetch("ENTRA_CLIENT_SECRET", Rails.env.test? ? "test-client-secret" : "not-configured"),
    tenant_id: ENV.fetch("ENTRA_TENANT_ID", Rails.env.test? ? "test-tenant-id" : "common")
end

OmniAuth.config.on_failure = proc { |env|
  Auth::CallbacksController.action(:failure).call(env)
}

if Rails.env.production? && !ENV["SECRET_KEY_BASE_DUMMY"]
  %w[ENTRA_CLIENT_ID ENTRA_CLIENT_SECRET ENTRA_TENANT_ID].each do |key|
    raise "Missing required environment variable: #{key}" unless ENV[key].present?
  end
end
