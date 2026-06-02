osl_mysql_test 'hedgedoc' do
  username 'hedgedoc'
  password 'hedgedoc'
end

osl_hedgedoc 'hedgedoc.example.org' do
  db_dialect 'mysql'
  db_host node['ipaddress']
  db_name 'hedgedoc'
  db_user 'hedgedoc'
  db_password 'hedgedoc'
  session_secret 'a' * 32
end
