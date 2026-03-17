Rails.application.config.middleware.use OmniAuth::Builder do
  provider :entra_id,
    client_id: ENV.fetch("ENTRA_CLIENT_ID"),
    client_secret: ENV.fetch("ENTRA_CLIENT_SECRET"),
    tenant_id: ENV.fetch("ENTRA_TENANT_ID")
end

OmniAuth.config.on_failure = proc { |env|
  Auth::CallbacksController.action(:failure).call(env)
}
