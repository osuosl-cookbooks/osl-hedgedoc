# osl-hedgedoc

Installs and configures [HedgeDoc](https://hedgedoc.org), a collaborative
markdown editor. HedgeDoc runs as the official `quay.io/hedgedoc/hedgedoc`
container via Docker Compose and connects to an external PostgreSQL or
MySQL/MariaDB database. TLS is expected to be terminated by an external HAProxy
node; the cookbook serves plain HTTP on the backend port and opens that port in
the firewall (restricted to OSL-managed networks) so the proxy host can reach
it.

## Requirements

### Platforms

- AlmaLinux 9+

### Cookbooks

- `osl-docker`
- `osl-firewall`

## Resources

### `osl_hedgedoc`

Deploys a HedgeDoc instance. The database (PostgreSQL or MySQL/MariaDB) is
managed separately and supplied via properties.

Each instance is self-contained under `/data/hedgedoc/<name>`, so multiple
instances can run on the same host. Give each one a unique `name`/`domain` and a
distinct `port`.

```ruby
osl_hedgedoc 'pad.example.org' do
  db_host   'db.example.org'
  db_name   'hedgedoc'
  db_user   'hedgedoc'
  db_password node.run_state['hedgedoc_db_password'] # from an encrypted data bag
  session_secret node.run_state['hedgedoc_session_secret']
end
```

| Property | Default | Description |
|---|---|---|
| `domain` | name | Public domain (used for generated URLs) |
| `db_dialect` | `'postgres'` | `postgres` or `mysql` |
| `db_host` | _required_ | Database host |
| `db_port` | 5432 / 3306 | Database port (defaults by dialect) |
| `db_name` | _required_ | Database name |
| `db_user` | _required_ | Database user |
| `db_password` | _required_ | Database password (sensitive) |
| `session_secret` | _required_ | HedgeDoc session secret (sensitive) |
| `version` | `'latest'` | HedgeDoc image tag |
| `port` | `3000` | Host port published for the proxy |
| `timezone` | `'UTC'` | Container timezone |
| `allow_anonymous` | `true` | Allow anonymous usage |
| `allow_email_register` | `true` | Allow email account registration |
| `ldap` | `{}` | Hash of LDAP settings; keys map to `CMD_LDAP_<KEY>` (sensitive) |
| `oauth2` | `{}` | Hash of OAuth2/OIDC settings; keys map to `CMD_OAUTH2_<KEY>` (sensitive) |
| `intro_md` | _unset_ | Inline markdown for a custom landing page (mounted over `public/intro.md`) |
| `intro_source` | _unset_ | `cookbook_file` name for the landing page (alternative to `intro_md`) |
| `intro_cookbook` | calling cookbook | Cookbook that ships `intro_source` |
| `extra_options` | `{}` | Hash of additional `CMD_*` settings rendered into the `.env` |

A custom landing page can be supplied two ways (mutually exclusive). Inline:

```ruby
osl_hedgedoc 'pad.example.org' do
  # ...
  intro_md "# Welcome\n\nOur HedgeDoc instance.\n"
end
```

Or from a `cookbook_file` shipped in your wrapper cookbook (often easier to
manage). By default it is pulled from the cookbook that declares the resource;
set `intro_cookbook` to pull from another:

```ruby
osl_hedgedoc 'pad.example.org' do
  # ...
  intro_source 'intro.md' # files/intro.md in the calling cookbook
end
```

### LDAP and OpenID Connect

LDAP and generic OAuth2 / OpenID Connect auth are configured via the `ldap` and
`oauth2` hashes. Each key is upper-cased and prefixed with `CMD_LDAP_` /
`CMD_OAUTH2_` to form the environment variable — e.g. `url` → `CMD_LDAP_URL`,
`client_id` → `CMD_OAUTH2_CLIENT_ID` (see the
[HedgeDoc configuration docs](https://docs.hedgedoc.org/configuration/) for the
full list of keys). Use HedgeDoc's exact spelling (`providername`,
`user_profile_url`, etc.). Both properties are `sensitive`, and the rendered
`.env` is sensitive too, so credentials stay out of Chef output.

```ruby
osl_hedgedoc 'pad.example.org' do
  # ...
  ldap(
    'url'          => 'ldaps://ldap.example.org',
    'searchbase'   => 'ou=people,dc=example,dc=org',
    'searchfilter' => '(uid={{username}})',
    'providername' => 'Example LDAP'
  )
  oauth2(
    'providername'      => 'Example SSO',
    'client_id'         => node.run_state['hedgedoc_oauth_id'],
    'client_secret'     => node.run_state['hedgedoc_oauth_secret'],
    'authorization_url' => 'https://idp.example.org/authorize',
    'token_url'         => 'https://idp.example.org/token',
    'user_profile_url'  => 'https://idp.example.org/userinfo',
    'scope'             => 'openid email profile'
  )
end
```

> **Customization note:** HedgeDoc 1.x does not support custom logos, favicons,
> or themes — that is planned for HedgeDoc 2.0. The only supported override is
> the landing page (via `intro_md` or `intro_source`). All behavioral settings
> (auth providers, SMTP, upload backends, privacy/terms/imprint URLs, etc.) are
> `CMD_*` env vars and can be set through `extra_options`.

Any HedgeDoc setting that isn't a first-class property can be passed through
`extra_options` using its full environment variable name:

```ruby
osl_hedgedoc 'pad.example.org' do
  # ...
  extra_options(
    'CMD_ALLOW_FREEURL'      => true,
    'CMD_DEFAULT_PERMISSION' => 'limited',
    'CMD_IMAGE_UPLOAD_TYPE'  => 'filesystem'
  )
end
```

## Contributing

1. Fork the repository on GitHub
1. Create a named feature branch (like `username/add_component_x`)
1. Write tests for your change
1. Write your change
1. Run the tests, ensuring they all pass
1. Submit a pull request on GitHub

## License and Authors

- Author:: Oregon State University <chef@osuosl.org>

```text
Copyright:: 2026, Oregon State University

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
