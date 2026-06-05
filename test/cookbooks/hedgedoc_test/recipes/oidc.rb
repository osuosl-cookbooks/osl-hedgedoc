osl_postgresql_test 'hedgedoc' do
  username 'hedgedoc'
  password 'hedgedoc'
end

# Fake OAuth2/OIDC settings -- HedgeDoc only contacts the provider during an
# actual login, so it starts fine with these and we can verify the strategy is
# wired up.
osl_hedgedoc 'hedgedoc.example.org' do
  db_host node['ipaddress']
  db_name 'hedgedoc'
  db_user 'hedgedoc'
  db_password 'hedgedoc'
  session_secret 'a' * 32
  oauth2(
    'providername' => 'Example SSO',
    'client_id' => 'hedgedoc',
    'client_secret' => 'fakesecret',
    'scope' => 'openid email profile',
    'authorization_url' => 'https://idp.example.org/authorize',
    'token_url' => 'https://idp.example.org/token',
    'user_profile_url' => 'https://idp.example.org/userinfo',
    'user_profile_username_attr' => 'preferred_username',
    'user_profile_display_name_attr' => 'name',
    'user_profile_email_attr' => 'email'
  )
end
