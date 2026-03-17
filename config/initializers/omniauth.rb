entra_client_id = ENV["ENTRA_CLIENT_ID"].presence || (Rails.env.test? ? "test-client-id" : nil)
entra_client_secret = ENV["ENTRA_CLIENT_SECRET"].presence || (Rails.env.test? ? "test-client-secret" : nil)
entra_tenant_id = ENV["ENTRA_TENANT_ID"].presence || (Rails.env.test? ? "test-tenant-id" : nil)

if entra_client_id.present? && entra_client_secret.present? && entra_tenant_id.present?
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :entra_id,
      client_id: entra_client_id,
      client_secret: entra_client_secret,
      tenant_id: entra_tenant_id
  end
end

OmniAuth.config.on_failure = proc { |env|
  Auth::CallbacksController.action(:failure).call(env)
}
