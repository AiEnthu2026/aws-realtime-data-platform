resource "aws_cognito_user_pool" "api" {
  name           = "${local.name_prefix}-api"
  user_pool_tier = "LITE"
}

resource "aws_cognito_user_pool_domain" "api" {
  domain       = "${local.name_prefix}-api-${substr(md5(local.account_id), 0, 8)}"
  user_pool_id = aws_cognito_user_pool.api.id
}

resource "aws_cognito_resource_server" "api" {
  identifier   = "rtdp-api"
  name         = "${local.name_prefix}-api"
  user_pool_id = aws_cognito_user_pool.api.id

  scope {
    scope_name        = "read"
    scope_description = "Read vehicle position queries"
  }
}

resource "aws_cognito_user_pool_client" "api_client" {
  name                                 = "${local.name_prefix}-api-client"
  user_pool_id                         = aws_cognito_user_pool.api.id
  generate_secret                      = true
  allowed_oauth_flows                  = ["client_credentials"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = aws_cognito_resource_server.api.scope_identifiers
  supported_identity_providers         = ["COGNITO"]
  access_token_validity                = 60

  token_validity_units {
    access_token = "minutes"
  }
}