# encoding: UTF-8

module Vines
  module Command
    class Migrate
      def run(opts)
        raise 'vines migrate <domain>' unless opts[:args].size == 1
        require opts[:config]
        domain = opts[:args].first
        unless storage = Config.instance.vhost(domain).storage rescue nil
          raise "#{domain} virtual host not found in conf/config.rb"
        end
        unless storage.respond_to?(:migrate)
          raise "SQL storage can not migrate"
        end
        begin
          storage.migrate
        rescue => e
          raise "Migration failed: #{e.message}"
        end
      end
    end
  end
end
