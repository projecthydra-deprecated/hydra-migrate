module Hydra
  module Migrate
    class Dispatcher
      def migrations
        @migrations || reset!
      end
      protected :migrations

      def reset!
        @migrations ||= Hash.new { |h,k| h[k] = [] }
      end

      def load_migrations(path)
        $stderr.puts "loading migrations from #{path}"
        Dir[File.join(path,'**','*.rb')].each { |migration_file|
          existing_migrations = ObjectSpace.each_object(Hydra::Migrate::Migration).to_a
          load(migration_file)
          new_migrations = ObjectSpace.each_object(Hydra::Migrate::Migration).to_a - existing_migrations
          new_migrations.each { |klass| klass.new(self) }
        }
      end

      def define_migration(signature={}, block)
        self.migrations[signature[:for]] << { :from=>signature[:from].to_s, :to=>signature[:to].to_s, :block=>block }
      end

      def migrations_for(target, constraints={})
        raise "Not a migratable object: #{target.inspect}" unless target.is_a?(Hydra::ModelMixins::Migratable)
        if self.migrations.has_key?(target.class)
          migrations[target.class].select { |v| 
            v[:from].to_s == constraints[:from].to_s and (constraints[:to].nil? or v[:to].to_s == constraints[:to].to_s)
          }
        else
          return []
        end
      end

      def can_migrate?(object, constraints={})
        object.is_a?(Hydra::ModelMixins::Migratable) and not migrations_for(object, {:from=>object.current_migration}.merge(constraints)).empty?
      end

      def migrate!(object, to=nil, opts={})
        raise "Not a migratable object: #{object.inspect}" unless object.is_a?(Hydra::ModelMixins::Migratable)
        migrations_for(object, :from=>object.current_migration, :to=>to).each do |migration|
          migration[:block].call(object, to, self)
          object.migrationInfo.migrate(migration[:to])
          object.current_migration = migration[:to]
          object.save unless opts[:dry_run]
        end
        object
      end
    end
  end
end