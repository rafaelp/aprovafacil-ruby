require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "AprovafacilRuby" do
  
  before(:each) do
    @config_file = File.expand_path(File.dirname(__FILE__) + '/fixtures/dummy-config.yml')
    @af = AprovaFacil.new(@config_file)
  end
  
  describe "initialize" do
      
    it "should raise exception if config file nil or empty" do
      lambda {
        AprovaFacil.new(nil)
      }.should raise_exception(ArgumentError, "config_file must be a valid file path")
    end

    it "should raise exception if config file not found" do
      lambda {
        AprovaFacil.new("/tmp/config-file-that-does-not-exists.yml")
      }.should raise_exception(Errno::ENOENT, "No such file or directory - /tmp/config-file-that-does-not-exists.yml")
    end

    it "should keep config_file" do
      @af.instance_variable_get(:@config_file).should == @config_file
    end

    it "should keep environment" do
      af = AprovaFacil.new(@config_file, 'production')
      af.instance_variable_get(:@environment).should == 'production'
    end

    it "should set default environment to test" do
      af = AprovaFacil.new(@config_file)
      af.instance_variable_get(:@environment).should == 'test'
    end

  end
  
  describe "config" do
    
    before(:all) do
      @test_config = {
        "node1" => {
          "test" => 1
        },
        "node2" => {
          "test" => 2
        }
      }
      @development_config = {
        "node3" => {
          "test" => 3,
          "test" => 4
        }
      }
    end

    it "should parse configuration from file" do
      file = mock()
      File.should_receive(:open).with(@config_file).and_return(file)
      YAML.should_receive(:load).with(file).and_return(@test_config)
      @af.config
    end
    
    it "should store config" do
      @af.config
      @af.instance_variable_get(:@config).should == @test_config
    end
    
    it "should cache config" do
      @af.should_receive(:parse_config).once.and_return({'test' => @test_config})
      @af.config
      @af.config
      @af.config
    end
    
    it "should get config from correct environment" do
      @af = AprovaFacil.new(@config_file, 'development')
      @af.config.should == @development_config
    end
    
  end
  
  describe "APC" do

    before(:each) do
      config_file = File.expand_path(File.dirname(__FILE__) + '/fixtures/config.yml')
      @af = AprovaFacil.new(config_file)
    end

    before(:all) do
      @valid_apc_params = {
        :ValorDocumento => 1.99,
        :QuantidadeParcelas => 1,
        :NumeroCartao => '4073020000000002',
        :MesValidade => 12,
        :AnoValidade => 14,
        :CodigoSeguranca => 999,
        :EnderecoIPComprador => '200.255.108.6',
      }
      
      resultado_apc_file = File.expand_path(File.dirname(__FILE__) + '/fixtures/resultado_apc_erro.xml')      
      f = File.new(resultado_apc_file, "r")
      @resultado_apc = f.read
      f.close
      
      FakeWeb.register_uri(:post, "http://teste.aprovafacil.com/cgi-bin/APFW/usuario/APC", :body => @resultado_apc)
    end
  
    it "should validates presence of ValorDocumento" do
      ret = @af.apc
      ret["ErroValidacao"].should include({:field => :ValorDocumento, :message => :blank})
    end
    
    it "should validates presence of QuantidadeParcelas" do
      ret = @af.apc
      ret["ErroValidacao"].should include({:field => :QuantidadeParcelas, :message => :blank})
    end

    it "should validates presence of NumeroCartao" do
      ret = @af.apc
      ret["ErroValidacao"].should include({:field => :NumeroCartao, :message => :blank})
    end

    it "should validates presence of MesValidade" do
      ret = @af.apc
      ret["ErroValidacao"].should include({:field => :MesValidade, :message => :blank})
    end
    
    it "should validates presence of AnoValidade" do
      ret = @af.apc
      ret["ErroValidacao"].should include({:field => :AnoValidade, :message => :blank})
    end

    it "should validates presence of CodigoSeguranca" do
      ret = @af.apc
      ret["ErroValidacao"].should include({:field => :CodigoSeguranca, :message => :blank})
    end

    it "should validates presence of EnderecoIPComprador" do
      ret = @af.apc
      ret["ErroValidacao"].should include({:field => :EnderecoIPComprador, :message => :blank})
    end

    it "should validates length of NumeroDocumento" do
      ret = @af.apc({:NumeroDocumento => 'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeeef'})
      ret["ErroValidacao"].should include({:field => :NumeroDocumento, :message => :too_long})
    end

    it "should validates length of NomePortadorCartao" do
      ret = @af.apc({:NomePortadorCartao => 'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeeef'})
      ret["ErroValidacao"].should include({:field => :NomePortadorCartao, :message => :too_long})
    end

    it "should validates length of NumeroCartao" do
      ret = @af.apc({:NumeroCartao => 'aaaaaaaaaabbbbbbbbbb'})
      ret["ErroValidacao"].should include({:field => :NumeroCartao, :message => :too_long})
    end

    it "should validates numericality of ValorDocumento" do
      ret = @af.apc({:ValorDocumento => 'texto'})
      ret["ErroValidacao"].should include({:field => :ValorDocumento, :message => :not_a_number})
    end
  
    it "should validates numericality of QuantidadeParcelas" do
      ret = @af.apc({:QuantidadeParcelas => 'texto'})
      ret["ErroValidacao"].should include({:field => :QuantidadeParcelas, :message => :not_a_number})
    end

    it "should validates numericality of QuantidadeParcelas with only integer" do
      ret = @af.apc({:QuantidadeParcelas => 1.1})
      ret["ErroValidacao"].should include({:field => :QuantidadeParcelas, :message => :not_a_number})
    end

    it "should validates inclusion of Bandeira" do
      ret = @af.apc({:Bandeira => 'bandeirainvalida'})
      ret["ErroValidacao"].should include({:field => :Bandeira, :message => :inclusion})
    end

    it "should raise exception if config[:apc_url] not found" do
      lambda {
        @af.instance_variable_set(:@config, {:apc_url => nil})
        @af.apc(@valid_apc_params)
      }.should raise_exception("You should set apc_url variable in configuration file with correct APC URL")
    end

    it "should make a post request to AprovaFacil" do
      @af.should_receive(:do_post).with("http://teste.aprovafacil.com/cgi-bin/APFW/usuario/APC", @valid_apc_params).once.and_return({})
      @af.apc(@valid_apc_params)
    end
    
    it "should return data structure of response" do
      @af.should_receive(:do_post).once.and_return({"Node1" => "test"})
      ret = @af.apc(@valid_apc_params)
      ret.should == {"ErroValidacao" => nil, "Node1" => "test"}
    end
    
  end

  describe "CAP" do

    before(:each) do
      config_file = File.expand_path(File.dirname(__FILE__) + '/fixtures/config.yml')
      @af = AprovaFacil.new(config_file)
    end

    before(:all) do
      @valid_cap_params_by_NumeroDocumento = {
        :NumeroDocumento => '123ABC'
      }
      @valid_cap_params_by_Transacao = {
        :Transacao => '123ABC'
      }
      
      resultado_cap_file = File.expand_path(File.dirname(__FILE__) + '/fixtures/resultado_cap_erro.xml')
      f = File.new(resultado_cap_file, "r")
      @resultado_cap = f.read
      f.close
      
      FakeWeb.register_uri(:post, "http://teste.aprovafacil.com/cgi-bin/APFW/usuario/CAP", :body => @resultado_cap)
    end
  
    it "should validates presence of NumeroDocumento" do
      ret = @af.cap
      ret["ErroValidacao"].should include({:field => :NumeroDocumento, :message => :blank})
    end

    it "should validates presence of Transacao" do
      ret = @af.cap
      ret["ErroValidacao"].should include({:field => :Transacao, :message => :blank})
    end

    it "should not validates presence of Transacao when NumeroDocumento is passed" do
      ret = @af.cap(@valid_cap_params_by_NumeroDocumento)
      ret["ErroValidacao"].should be_nil
    end

    it "should not validates presence of NumeroDocumento when Transacao is passed" do
      ret = @af.cap(@valid_cap_params_by_Transacao)
      ret["ErroValidacao"].should be_nil
    end

    it "should make a post request to AprovaFacil" do
      @af.should_receive(:do_post).with("http://teste.aprovafacil.com/cgi-bin/APFW/usuario/CAP", @valid_cap_params_by_Transacao).once.and_return({})
      @af.cap(@valid_cap_params_by_Transacao)
    end
    
    it "should return data structure of response" do
      @af.should_receive(:do_post).once.and_return({"Node1" => "test"})
      ret = @af.cap(@valid_cap_params_by_Transacao)
      ret.should == {"ErroValidacao" => nil, "Node1" => "test"}
    end

  end

  describe "CAN" do

    before(:each) do
      config_file = File.expand_path(File.dirname(__FILE__) + '/fixtures/config.yml')
      @af = AprovaFacil.new(config_file)
    end

    before(:all) do
      @valid_can_params_by_NumeroDocumento = {
        :NumeroDocumento => '123ABC'
      }
      @valid_can_params_by_Transacao = {
        :Transacao => '123ABC'
      }
      
      resultado_can_file = File.expand_path(File.dirname(__FILE__) + '/fixtures/cancelamento_marcado_erro.xml')
      f = File.new(resultado_can_file, "r")
      @resultado_can = f.read
      f.close
      
      FakeWeb.register_uri(:post, "http://teste.aprovafacil.com/cgi-bin/APFW/usuario/CAN", :body => @resultado_can)
    end
  
    it "should validates presence of NumeroDocumento" do
      ret = @af.can
      ret["ErroValidacao"].should include({:field => :NumeroDocumento, :message => :blank})
    end

    it "should validates presence of Transacao" do
      ret = @af.can
      ret["ErroValidacao"].should include({:field => :Transacao, :message => :blank})
    end

    it "should not validates presence of Transacao when NumeroDocumento is passed" do
      ret = @af.can(@valid_can_params_by_NumeroDocumento)
      ret["ErroValidacao"].should be_nil
    end

    it "should not validates presence of NumeroDocumento when Transacao is passed" do
      ret = @af.can(@valid_can_params_by_Transacao)
      ret["ErroValidacao"].should be_nil
    end

    it "should make a post request to AprovaFacil" do
      @af.should_receive(:do_post).with("http://teste.aprovafacil.com/cgi-bin/APFW/usuario/CAN", @valid_can_params_by_Transacao).once.and_return({})
      @af.can(@valid_can_params_by_Transacao)
    end
    
    it "should return data structure of response" do
      @af.should_receive(:do_post).once.and_return({"Node1" => "test"})
      ret = @af.can(@valid_can_params_by_Transacao)
      ret.should == {"ErroValidacao" => nil, "Node1" => "test"}
    end
    
  end

  describe "approve" do
    
    it "should call APC"
    it "should store response from APC"
    it "should store Transacao"
    it "should store error messages from response if not approved"
    it "should return true if debit was approved"
    it "should return false if debit was not approved"
    
  end
  
  describe "approved?" do
    
    it "should return true if last APC request was approved"
    it "should return false if last APC request was not approved"
    
  end
  
  describe "confirm" do
    
    it "should call CAP with Transacao stored by aprove"
    it "should store response from CAP"
    it "should store Transacao"
    it "should store error messages from response if not confirmed"
    it "should return true if debit was confirmed"
    it "should return false if debit was not confirmed"
    
  end
  
  describe "confirmed?" do
    
    it "should return true if last CAP request was confirmed"
    it "should return false if last CAP request was not confirmed"
    
  end
  
  describe "cancel" do
    
    it "should call CAN with Transacao stored by confirm"
    it "should store response from CAN"
    it "should store Transacao"
    it "should store error messages from response if not canceled"
    it "should return true if debit was canceled"
    it "should return false if debit was not canceled"
    
  end
  
  describe "canceled?" do
    
    it "should return true if last CAN request was canceled"
    it "should return false if last CAN request was not canceled"
    
  end

  describe "error?" do
    
    it "should return true if last request was not complete"
    
  end

  describe "do_post" do

    before(:all) do
      dirty_data_structure = File.expand_path(File.dirname(__FILE__) + '/fixtures/dirty_data_structure.xml')      
      f = File.new(dirty_data_structure, "r")
      @dirty_data_structure = f.read
      f.close
      
      @http_mock = mock('Net::HTTPResponse')
      @http_mock.stub(:code => '200', :message => "OK", :content_type => "text/html", :body => @dirty_data_structure)
      Net::HTTP.stub!(:post_form).and_return(@http_mock)

      @url = "http://teste.aprovafacil.com/cgi-bin/APFW/usuario/APC"
      @params = {:q => 'just testing'}
    end
    
    it "should make a request on received url with received params" do
      parsed_uri = mock()
      URI.should_receive(:parse).with(@url).once.and_return(parsed_uri)       
      Net::HTTP.should_receive(:post_form).with(parsed_uri, @params).once.and_return(@http_mock)
      @af.do_post(@url,@params)
    end
    
    it "should parse response with XmlSimple" do
      XmlSimple.should_receive(:xml_in).with(@dirty_data_structure,{ "keeproot" => false, "forcearray" => false })
      @af.do_post(@url,@params)
    end

    it "should strip values from parsed response" do
      ret = mock()
      ret.should_receive(:strip_values!).once
      XmlSimple.should_receive(:xml_in).with(@dirty_data_structure,{ "keeproot" => false, "forcearray" => false }).and_return(ret)
      @af.do_post(@url,@params)      
    end
    
    it "should return data structure parsed correctly" do
      ret = @af.do_post(@url,@params)
      ret.should == {"EnderecoAVS"=>{"Complemento"=>{}, "Endereco"=>{}, "Cep"=>{}, "Numero"=>{}}, "TransacaoAprovada"=>"False", "NacionalidadeEmissor"=>{}, "NumeroDocumento"=>{}, "CodigoAutorizacao"=>{}, "ComprovanteAdministradora"=>{}, "Transacao"=>"73397880137091", "ResultadoSolicitacaoAprovacao"=>"Nao Autorizado - 32", "ResultadoAVS"=>{}, "CartaoMascarado"=>"407302******0002"}
    end
    
  end
  

end
