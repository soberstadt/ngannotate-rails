module Ngannotate
module ProcessorCommon
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def name
      'Ngannotate::Processor'
    end

    def shared_exec_context
      @shared_exec_context ||=
        begin
          ::Rails.logger.info "ng-prepare"
          ngannotate_source = File.open(File.expand_path('../../../vendor/ngannotate.js', __FILE__)).read
          ExecJS.compile "window = {};" + ngannotate_source
        end
    end
  end

  def process_data(input)
    data = input[:data]
    file = input[:filename]

    handle = need_process?(input)
    state = handle ? :process : (ignore_file?(input) ? :ignore : :skip)
    ::Rails.logger.info "ng-#{state}: #{file}"
    return data unless handle

    opt = { add: true }.merge!(parse_ngannotate_options)
    r = exec_context.call 'window.annotate', data, opt
    r['src']
  end

  def exec_context
    @exec_context ||= self.class.shared_exec_context
  end

  def config
    ::Rails.configuration.ng_annotate
  end

  #
  # Is processing done for current file. This is determined by 3 checks
  #
  # - config.ignore_paths
  # - config.process
  # - NG_FORCE=true env option
  #
  def need_process?(input)
    force_process = ENV['NG_FORCE'] == 'true'
    !ignore_file?(input) && (force_process || config.process)
  end

  #
  # @return true if current file is ignored
  #
  def ignore_file?(input)
    file = input[:filename]
    config.ignore_paths.any? do |p|
      if p.is_a? Proc
        p.call(file)
      else
        file.index(p)
      end
    end
  end

  #
  # Parse extra options for ngannotate
  #
  def parse_ngannotate_options
    opt = config.options.clone

    if ENV['NG_OPT']
      opt_str = ENV['NG_OPT']
      if opt_str
        opt = Hash[opt_str.split(',').map { |e| e.split('=') }]
        opt.symbolize_keys!
      end
    end

    regexp = ENV['NG_REGEXP'] || config.regexp
    if regexp
      opt[:regexp] = regexp
    end

    opt
  end
end
end
