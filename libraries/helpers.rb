module OSLHedgedoc
  module Cookbook
    module Helpers
      # HedgeDoc's container runs the app as the `hedgedoc` user (uid/gid 10000).
      # The bind-mounted uploads directory must be owned by that uid so the app
      # can write to it.
      def hedgedoc_uid
        10_000
      end

      def hedgedoc_gid
        10_000
      end

      # Per-instance data directory. Each instance is self-contained here so that
      # multiple HedgeDoc instances can run on the same host.
      def hedgedoc_base_dir(name)
        "/data/hedgedoc/#{name}"
      end

      # Sanitized identifier reused for the Compose project, firewall chain, and
      # image resource. Compose project names cannot contain dots, which domains
      # (the usual resource name) almost always do.
      def hedgedoc_instance(name)
        name.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/(\A-+|-+\z)/, '')
      end

      # iptables chain name for the instance's firewall rule: a `hedgedoc-`
      # prefix plus the instance, truncated to the 28-character limit that
      # iptables/ip6tables enforce on chain names (domains routinely exceed it).
      def hedgedoc_firewall_chain(instance)
        "hedgedoc-#{instance}"[0, 28].sub(/-+\z/, '')
      end

      # Default database port for a given dialect.
      def hedgedoc_db_port(dialect)
        dialect == 'postgres' ? 5432 : 3306
      end

      # Sequelize-style connection string HedgeDoc consumes via CMD_DB_URL.
      def hedgedoc_db_url(dialect:, user:, password:, host:, port:, name:)
        "#{dialect}://#{user}:#{password}@#{host}:#{port}/#{name}"
      end
    end
  end
end

Chef::DSL::Recipe.include ::OSLHedgedoc::Cookbook::Helpers
Chef::Resource.include ::OSLHedgedoc::Cookbook::Helpers
