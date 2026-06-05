osl_hedgedoc 'hedgedoc.example.org' do
  db_host node['ipaddress']
  db_name 'hedgedoc'
  db_user 'hedgedoc'
  db_password 'hedgedoc'
  session_secret 'a' * 32
  intro_source 'intro.md'
end
