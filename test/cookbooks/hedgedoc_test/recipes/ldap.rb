osl_postgresql_test 'hedgedoc' do
  username 'hedgedoc'
  password 'hedgedoc'
end

# Fake LDAP settings -- HedgeDoc only contacts the LDAP server when a user logs
# in, so it starts fine with these and we can verify the strategy is wired up.
osl_hedgedoc 'hedgedoc.example.org' do
  db_host node['ipaddress']
  db_name 'hedgedoc'
  db_user 'hedgedoc'
  db_password 'hedgedoc'
  session_secret 'a' * 32
  ldap(
    'url' => 'ldaps://ldap.example.org',
    'binddn' => 'cn=hedgedoc,ou=services,dc=example,dc=org',
    'bindcredentials' => 'fakepassword',
    'searchbase' => 'ou=people,dc=example,dc=org',
    'searchfilter' => '(uid={{username}})',
    'useridfield' => 'uid',
    'providername' => 'Example LDAP'
  )
end
