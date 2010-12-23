require 'net/http'
require 'uri'
require 'YAML'
require 'rubygems'
require 'xmlsimple'
require 'hash_strip_values'

class AprovaFacil
  
  attr_reader :transaction, :error_message, :last_response

	def initialize(config_file, environment = 'test')
	  raise(ArgumentError, "config_file must be a valid file path") if config_file.nil? or config_file.empty?
    raise(Errno::ENOENT, config_file) unless File.exists? config_file
	  @config_file = config_file
	  @environment = environment
	  @errors = []
	end
	
	def config
    @config = parse_config[@environment] if @config.nil?
	  return @config
  end
  
  def apc(params = {})
    @params = params
    validates_presence_of :ValorDocumento
    validates_presence_of :QuantidadeParcelas
    validates_length_of :NumeroDocumento, :maximum => 50
    validates_numericality_of :ValorDocumento
    validates_numericality_of :QuantidadeParcelas, :only_integer => true

    unless params[:TransacaoAnterior]
      validates_presence_of :NumeroCartao
      validates_presence_of :MesValidade
      validates_presence_of :AnoValidade
      validates_presence_of :CodigoSeguranca
      validates_presence_of :EnderecoIPComprador
      validates_length_of :NomePortadorCartao, :maximum => 50
      validates_length_of :NumeroCartao, :maximum => 19
      validates_inclusion_of :Bandeira, :in => %w( VISA MASTERCARD DINERS AMEX HIPERCARD JCB SOROCRED AURA )
    end
    return {"ErroValidacao" => @errors} unless @errors.empty?
    
    raise "You should set apc_url variable in configuration file with correct APC URL" if config["apc_url"].nil?
    ret = do_post(config["apc_url"], params)
    {"ErroValidacao" => nil}.merge(ret)
  end

  def cap(params = {})
    @params = params
    validates_presence_of :NumeroDocumento if @params[:Transacao].nil?
    validates_presence_of :Transacao if @params[:NumeroDocumento].nil?
    return {"ErroValidacao" => @errors} unless @errors.empty?
    
    raise "You should set cap_url variable in configuration file with correct CAP URL" if config["cap_url"].nil?
    ret = do_post(config["cap_url"], @params)
    {"ErroValidacao" => nil}.merge(ret)
  end

  def can(params = {})
    @params = params
    validates_presence_of :NumeroDocumento if @params[:Transacao].nil?
    validates_presence_of :Transacao if @params[:NumeroDocumento].nil?
    return {"ErroValidacao" => @errors} unless @errors.empty?
    
    raise "You should set can_url variable in configuration file with correct CAN URL" if config["can_url"].nil?
    ret = do_post(config["can_url"], @params)
    {"ErroValidacao" => nil}.merge(ret)
  end
  
  def do_post(url, params)
    response = Net::HTTP.post_form(URI.parse(url), params)
    ret = XmlSimple.xml_in(response.body, { "keeproot" => false, "forcearray" => false })
    ret.strip_values! unless ret.nil?
  end

  def approve(params)
    @apc_response = apc(params)
    @last_response = @apc_response
    @transaction = @apc_response["Transacao"]
    @error_message = approved? ? nil : @apc_response["ResultadoSolicitacaoAprovacao"]
    return approved?
  end
  
  def confirm(params)
    @cap_response = cap(params)
    @last_response = @cap_response
    @error_message = confirmed? ? nil : @cap_response["ResultadoSolicitacaoConfirmacao"]
    return confirmed?
  end
  
  def cancel(params)
    @can_response = can(params)
    @last_response = @can_response
    @error_message = (cancelled? or to_cancel?) ? nil : @can_response["ResultadoSolicitacaoCancelamento"]
    return(cancelled? or to_cancel?)
  end

  def approved?
    raise "Call this method after approve" if @apc_response.nil?
    @apc_response["TransacaoAprovada"] == "True"
  end

  def confirmed?
    raise "Call this method after confirm" if @cap_response.nil?
    @cap_response["ResultadoSolicitacaoConfirmacao"].split("%20")[0] == "Confirmado"
  end

  def cancelled?
    raise "Call this method after cancel" if @can_response.nil?
    @can_response["ResultadoSolicitacaoCancelamento"].split("%20")[0] == "Cancelado"
  end

  def to_cancel?
    raise "Call this method after cancel" if @can_response.nil?
    (@can_response["ResultadoSolicitacaoCancelamento"].split("%20")[0] == "Cancelamento" and
    @can_response["ResultadoSolicitacaoCancelamento"].split("%20")[1] == "marcado" and
    @can_response["ResultadoSolicitacaoCancelamento"].split("%20")[2] == "para" and
    @can_response["ResultadoSolicitacaoCancelamento"].split("%20")[3] == "envio")
  end
  
  def error?
    !@error_message.nil?
  end
      
	protected


  def parse_config
    YAML::load(File.open(@config_file))
  end

  def validates_presence_of(field)
    value = @params[field.to_sym]
    if value.nil?
      @errors << {
        :field => field,
        :message => :blank,
      }
    end
  end

  def validates_length_of(field, range_options)
    value = @params[field.to_sym]
    return if value.nil?

    validity_checks = { :is => "==", :minimum => ">=", :maximum => "<=" }
    option = range_options.keys.first
    option_value = range_options[option]
    
    unless !value.nil? and value.size.method(validity_checks[option])[option_value]
      @errors << {
        :field => field,
        :message => {:is => :wrong_length, :minimum => :too_short, :maximum => :too_long}[option],
      }
    end
  end
  
  def validates_numericality_of(field, configuration = {})
    value = @params[field.to_sym]
    return if value.nil?

    if configuration[:only_integer]
      unless value.to_s =~ /\A[+-]?\d+\Z/
        @errors << {
          :field => field,
          :message => :not_a_number,
        }
      end
    else
      begin
        value = Kernel.Float(value)
      rescue ArgumentError, TypeError
        @errors << {
          :field => field,
          :message => :not_a_number,
        }
      end
    end
  end

  def validates_inclusion_of(field, configuration)
    value = @params[field.to_sym]
    return if value.nil?
    
    enum = configuration[:in] || configuration[:within]
    unless enum.include?(value)
      @errors << {
        :field => field,
        :message => :inclusion,
      }
    end
  end

end