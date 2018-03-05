# Copied from recipes/default.rb in: https://github.com/yyuu/chef-buildpack
#
# Copyright (C) 2015 Yamashita, Yuu
# Apache 2.0

package 'bash'
package 'curl'
package 'git'
package 'tar'

# provides/default.rb
module ::Buildpack
  def buildpack_info(name, buildpack_url, buildpack_dir = nil)
    buildpack_root = ::File.join(chef_file_cache_path, 'buildpacks')
    case buildpack_url
    when /\.tar\.gz$/
      {
        :format => :tgz,
        :buildpack_url => buildpack_url,
        :buildpack_dir => buildpack_dir || ::File.join(buildpack_root, name),
      }
    else
      if buildpack_url.index("#")
        repository, revision = buildpack_url.split("#", 2)
      else
        repository = buildpack_url
        revision = "HEAD"
      end
      {
        :format => :git,
        :buildpack_url => repository,
        :revision => revision,
        :buildpack_dir => buildpack_dir || ::File.join(buildpack_root, name),
      }
    end
  end

  def provision(info)
    case info[:format]
    when :git
      provision_git(info)
    when :tgz
      provision_tgz(info)
    else
      fail("Unknown buildpack format: #{info[:format].inspect}")
    end
  end

  def provision_tgz(info)
    buildpack_dir = info[:buildpack_dir]
    buildpack_url = info[:buildpack_url]
    bash "buildpack #{buildpack_dir}" do
      code <<-SH
        set -e
        set -x
        set -o pipefail
        tmpdir="$(mktemp -d /tmp/buildpack.XXXXXXXX)"
        on_exit() { rm -fr "${tmpdir}"; }
        trap on_exit EXIT
        cd "${tmpdir}"
        curl -L --fail --retry 3 --retry-delay 1 --connect-timeout 3 --max-time 30 #{::Shellwords.shellescape(buildpack_url)} -s -o - | tar zxf -
        mkdir -p #{::Shellwords.shellescape(::File.dirname(buildpack_dir))}
        rm -fr #{::Shellwords.shellescape(buildpack_dir)}
        mv -f * #{::Shellwords.shellescape(buildpack_dir)}
      SH
    end
  end

  def provision_git(info)
    buildpack_dir = info[:buildpack_dir]
    buildpack_url = info[:buildpack_url]
    bash "buildpack #{buildpack_dir}" do
      code <<-SH
        set -e
        set -x
        mkdir -p #{::Shellwords.shellescape(::File.dirname(buildpack_dir))}
        if [ -e #{::Shellwords.shellescape(::File.join(buildpack_dir, ".git"))} ]; then
          if [ -e #{::Shellwords.shellescape(::File.join(buildpack_dir, ".git", "shallow"))} ]; then
            rm -fr #{::Shellwords.shellescape(buildpack_dir)}
          fi
        else
          rm -fr #{::Shellwords.shellescape(buildpack_dir)}
        fi
        if [ -d #{::Shellwords.shellescape(buildpack_dir)} ]; then
          cd #{::Shellwords.shellescape(buildpack_dir)}
          git config remote.origin.url #{::Shellwords.shellescape(buildpack_url)}
          git config remote.origin.fetch "+refs/heads/*:refs/remote/origin/*"
          git fetch
        else
          git clone #{::Shellwords.shellescape(buildpack_url)} #{::Shellwords.shellescape(buildpack_dir)}
          cd #{::Shellwords.shellescape(buildpack_dir)}
        fi
        if git show-ref -q --verify #{::Shellwords.shellescape("refs/tags/#{info[:revision]}")}; then
          git reset --hard #{::Shellwords.shellescape("refs/tags/#{info[:revision]}")}
        else
          if git show-ref -q --verify #{::Shellwords.shellescape("refs/remotes/origin/#{info[:revision]}")}; then
            git reset --hard #{::Shellwords.shellescape("refs/remotes/origin/#{info[:revision]}")}
          else
            git reset --hard #{::Shellwords.shellescape(info[:revision])}
          fi
        fi
        git clean -d -f -x
      SH
    end
  end

  def invoke(buildpack_dir, command, args=[], environment={})
    executable = ::File.join(buildpack_dir, "bin", command)
    cmdline = Shellwords.shelljoin([executable] + args)
    cmdline = "env #{environment.map { |k, v| "#{k}='#{v}'" }.join(' ')} #{cmdline}"
    execute cmdline do
      only_if { ::File.exist?(executable) }
    end
  end

  def detect(buildpack_dir, build_dir, environment={})
    invoke(buildpack_dir, "detect", [build_dir], environment)
  end

  def compile(buildpack_dir, build_dir, cache_dir, env_dir, environment={})
    raise(ArgumentError.new("missing CACHE_DIR")) if cache_dir.nil?
    raise(ArgumentError.new("missing ENV_DIR")) if env_dir.nil?
    invoke(buildpack_dir, "compile", [build_dir, cache_dir, env_dir], environment)
  end

  def chef_file_cache_path
    '/var/chef/cache'
  end
end
::MItamae::RecipeContext.include(::Buildpack)

define :bash, code: '' do
  execute "bash[#{params[:name]}]" do
    command "bash -c #{params[:code].shellescape}"
  end
end

define(
  :buildpack,
  buildpack_url: 'https://github.com/heroku/heroku-buildpack-ruby.git',
  buildpack_dir: nil,
  environment: {},
  build_dir: nil, # required
  cache_dir: nil,
  env_dir: nil,
  activate_file: 'activate',
) do

  # action :detect
  info = buildpack_info(params[:name], params[:buildpack_url], params[:buildpack_dir])
  provision(info)
  detect(info[:buildpack_dir], params[:build_dir], params[:environment])

  # action :compile
  if params[:activate_file]
    template ::File.join(params[:build_dir], params[:activate_file]) do
      mode '0755'
      source 'files/activate.erb'
      variables({
        home: params[:build_dir],
      })
    end
    MItamae.logger.info("Created \`activate' script at #{params[:build_dir].inspect}.")
  end
  compile(info[:buildpack_dir], params[:build_dir], params[:cache_dir], params[:env_dir], params[:environment])
end
