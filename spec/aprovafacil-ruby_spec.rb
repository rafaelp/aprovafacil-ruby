require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "AprovafacilRuby" do

  before(:all) do
    @config_file = File.expand_path(File.dirname(__FILE__) + '/fixtures/config.yml')
    @config_file_cgi = File.expand_path(File.dirname(__FILE__) + '/fixtures/config-cgi.yml')
  end
  
  before(:each) do
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
        "mode" => "webservice",
        "node1" => {
          "test" => 1
        },
        "node2" => {
          "test" => 2
        }
      }
      @development_config = {
        "mode" => "cgi",
        "node3" => {
          "test" => 3,
          "test" => 4
        }
      }
    end

    before(:each) do
      @config_file = File.expand_path(File.dirname(__FILE__) + '/fixtures/dummy-config.yml')
      @af = AprovaFacil.new(@config_file)
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
    
    it "should set correct mode from config" do
      @af = AprovaFacil.new(@config_file, 'test')
      @af.cgi_mode?.should be_false

      @af = AprovaFacil.new(@config_file, 'development')
      @af.cgi_mode?.should be_true
    end
    
  end
  
  describe "APC" do

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
    
    context "TransacaoAnterior is present" do
      
      it "should validates presence of ValorDocumento" do
        ret = @af.apc({:TransacaoAnterior => '73412882291056'})
        ret["ErroValidacao"].should include({:field => :ValorDocumento, :message => :blank})
      end
    
      it "should validates presence of QuantidadeParcelas" do
        ret = @af.apc({:TransacaoAnterior => '73412882291056'})
        ret["ErroValidacao"].should include({:field => :QuantidadeParcelas, :message => :blank})
      end

      it "should not validates presence of NumeroCartao" do
        ret = @af.apc({:TransacaoAnterior => '73412882291056'})
        ret["ErroValidacao"].should_not include({:field => :NumeroCartao, :message => :blank})
      end

      it "should not validates presence of MesValidade" do
        ret = @af.apc({:TransacaoAnterior => '73412882291056'})
        ret["ErroValidacao"].should_not include({:field => :MesValidade, :message => :blank})
      end
    
      it "should not validates presence of AnoValidade" do
        ret = @af.apc({:TransacaoAnterior => '73412882291056'})
        ret["ErroValidacao"].should_not include({:field => :AnoValidade, :message => :blank})
      end

      it "should not validates presence of CodigoSeguranca" do
        ret = @af.apc({:TransacaoAnterior => '73412882291056'})
        ret["ErroValidacao"].should_not include({:field => :CodigoSeguranca, :message => :blank})
      end

      it "should not validates presence of EnderecoIPComprador" do
        ret = @af.apc({:TransacaoAnterior => '73412882291056'})
        ret["ErroValidacao"].should_not include({:field => :EnderecoIPComprador, :message => :blank})
      end

      it "should validates length of NumeroDocumento" do
        ret = @af.apc({:TransacaoAnterior => '73412882291056', :NumeroDocumento => 'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeeef'})
        ret["ErroValidacao"].should include({:field => :NumeroDocumento, :message => :too_long})
      end

      it "should not validates length of NomePortadorCartao" do
        ret = @af.apc({:TransacaoAnterior => '73412882291056', :NomePortadorCartao => 'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeeef'})
        ret["ErroValidacao"].should_not include({:field => :NomePortadorCartao, :message => :too_long})
      end

      it "should not validates length of NumeroCartao" do
        ret = @af.apc({:TransacaoAnterior => '73412882291056', :NumeroCartao => 'aaaaaaaaaabbbbbbbbbb'})
        ret["ErroValidacao"].should_not include({:field => :NumeroCartao, :message => :too_long})
      end

      it "should validates numericality of ValorDocumento" do
        ret = @af.apc({:TransacaoAnterior => '73412882291056', :ValorDocumento => 'texto'})
        ret["ErroValidacao"].should include({:field => :ValorDocumento, :message => :not_a_number})
      end
  
      it "should validates numericality of QuantidadeParcelas" do
        ret = @af.apc({:TransacaoAnterior => '73412882291056', :QuantidadeParcelas => 'texto'})
        ret["ErroValidacao"].should include({:field => :QuantidadeParcelas, :message => :not_a_number})
      end

      it "should validates numericality of QuantidadeParcelas with only integer" do
        ret = @af.apc({:TransacaoAnterior => '73412882291056', :QuantidadeParcelas => 1.1})
        ret["ErroValidacao"].should include({:field => :QuantidadeParcelas, :message => :not_a_number})
      end

      it "should not validates inclusion of Bandeira" do
        ret = @af.apc({:TransacaoAnterior => '73412882291056', :Bandeira => 'bandeirainvalida'})
        ret["ErroValidacao"].should_not include({:field => :Bandeira, :message => :inclusion})
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
        ret = @af.apc(@valid_apc_params)
        ret.should == {"TransacaoAprovada"=>"False", "EnderecoAVS"=>{"Complemento"=>{}, "Endereco"=>{}, "Cep"=>{}, "Numero"=>{}}, "NumeroDocumento"=>{}, "NacionalidadeEmissor"=>{}, "ErroValidacao"=>nil, "CodigoAutorizacao"=>{}, "ComprovanteAdministradora"=>{}, "ResultadoSolicitacaoAprovacao"=>"Nao Autorizado - 32", "Transacao"=>"73397880137091", "ResultadoAVS"=>{}, "CartaoMascarado"=>"407302******0002"}
      end
      
    end
    
    context "TransacaoAnterior is not present" do
  
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
        ret = @af.apc(@valid_apc_params)
        ret.should == {"TransacaoAprovada"=>"False", "EnderecoAVS"=>{"Complemento"=>{}, "Endereco"=>{}, "Cep"=>{}, "Numero"=>{}}, "NumeroDocumento"=>{}, "NacionalidadeEmissor"=>{}, "ErroValidacao"=>nil, "CodigoAutorizacao"=>{}, "ComprovanteAdministradora"=>{}, "ResultadoSolicitacaoAprovacao"=>"Nao Autorizado - 32", "Transacao"=>"73397880137091", "ResultadoAVS"=>{}, "CartaoMascarado"=>"407302******0002"}
      end
      
    end
    
  end

  describe "CAP" do

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
      ret = @af.cap(@valid_cap_params_by_Transacao)
      ret.should == {"ErroValidacao"=>nil, "ResultadoSolicitacaoConfirmacao"=>"Erro%20­%20Transa%E7%E3o%20a%20confirmar%20n%E3o%20encontrada%20ou \n%20jE1%20confirmada", "ComprovanteAdministradora"=>{}}
    end

  end

  describe "CAN" do

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
      ret = @af.can(@valid_can_params_by_Transacao)
      ret.should == {"ErroValidacao"=>nil, "ResultadoSolicitacaoCancelamento"=>"Erro%20­%20Transa%E7%E3o%20inv%E1lida", "NSUCancelamento"=>{}}
    end
    
  end
  
  describe "transaction" do
    
    it "should not be writable" do
      lambda {
        @af.transaction = "999"
      }.should raise_exception
    end
    
  end
  
  describe "error_message" do
    
    it "should not be writable" do
      lambda {
        @af.error_message = "Error Message"
      }.should raise_exception
    end
    
  end
  
  describe "last_response" do
    
    it "should not be writable" do
      lambda {
        @af.last_response = "Error Message"
      }.should raise_exception
    end
    
  end
  
  
  describe "End User methods" do

    before(:all) do
      @valid_params = {
        :ValorDocumento => 1.99,
        :QuantidadeParcelas => 1,
        :NumeroCartao => '4073020000000002',
        :MesValidade => 12,
        :AnoValidade => 14,
        :CodigoSeguranca => 999,
        :EnderecoIPComprador => '200.255.108.6',
      }
      @approved_apc_response = {"TransacaoAprovada" => "TRUE", "Transacao" => "9999", "ResultadoSolicitacaoAprovacao" => "00 ­ APROVADA"}
      @disapproved_apc_response = {"TransacaoAprovada" => "FALSE", "Transacao" => "8888", "ResultadoSolicitacaoAprovacao" => "Nao Autorizado - 32"}

      @success_cap_response_webservice = {"ResultadoSolicitacaoConfirmacao" => "Confirmado%2073263500055432"}
      @error_cap_response_webservice = {"ResultadoSolicitacaoConfirmacao" => "Erro%20­%20Transa%E7%E3o%20a%20confirmar%20n%E3o%20encontrada%20ou %20jE1%20confirmada"}

      @success_cap_response_cgi = {"ComprovanteAdministradora"=>{}, "ResultadoSolicitacaoAprovacao" => "Confirmado%2073263500055432"}
      @error_cap_response_cgi = {"ComprovanteAdministradora"=>{}, "ResultadoSolicitacaoAprovacao" => "Erro%20­%20Transa%E7%E3o%20a%20confirmar%20n%E3o%20encontrada%20ou %20jE1%20confirmada"}

      @cancelled_can_response = {"ResultadoSolicitacaoCancelamento" => "Cancelado%2073263500055432"}
      @to_cancel_can_response = {"ResultadoSolicitacaoCancelamento" => "Cancelamento%20marcado%20para%20envio%2073263500055432 "}
      @error_can_response = {"ResultadoSolicitacaoCancelamento" => "Erro%20­%20Transa%E7%E3o%20inv%E1lida"}

    end

    describe "approve" do
    
      it "should call APC once" do
        @af.should_receive(:apc).with(@valid_params).once.and_return(@approved_apc_response)
        @af.approve(@valid_params)
      end
    
      it "should store response from APC" do
        @af.should_receive(:apc).with(@valid_params).and_return(@approved_apc_response)
        @af.approve(@valid_params)
        @af.instance_variable_get(:@apc_response).should == @approved_apc_response
      end
      
      it "should store last response" do
        @af.should_receive(:apc).with(@valid_params).and_return(@approved_apc_response)
        @af.approve(@valid_params)
        @af.last_response.should == @approved_apc_response
      end
      
      context "when transaction was approved" do
        
        before(:each) do
          @af.stub!(:apc).with(@valid_params).and_return(@approved_apc_response)
        end
    
        it "should store transaction" do
          @af.approve(@valid_params)
          @af.transaction.should == @approved_apc_response["Transacao"]
        end
      
        it "should clear error message" do
          @af.instance_variable_set(:@error_message, "Error Message")
          @af.approve(@valid_params)
          @af.error_message.should be_nil
        end
      
        it "should return true" do
          @af.approve(@valid_params).should be_true
        end
      
      end

      context "when transaction was not approved" do
        
        before(:each) do
          @af.stub!(:apc).with(@valid_params).and_return(@disapproved_apc_response)
        end

        it "should store transaction" do
          @af.approve(@valid_params)
          @af.transaction.should == @disapproved_apc_response["Transacao"]
        end
    
        it "should store error messages from response" do
          @af.approve(@valid_params)
          @af.error_message.should == @disapproved_apc_response["ResultadoSolicitacaoAprovacao"]
        end
    
        it "should return false" do
          @af.approve(@valid_params).should be_false
        end
        
      end
    
    end
  

    describe "approved?" do

      it "should raise exception if no APC response" do
        lambda {
          @af.approved?
        }.should raise_exception("Call this method after approve")
      end

      it "should return true if last APC request was approved" do
        @af.instance_variable_set(:@apc_response, @approved_apc_response)
        @af.approved?.should be_true
      end
    
      it "should return false if last APC request was not approved" do
        @af.instance_variable_set(:@apc_response, @disapproved_apc_response)
        @af.approved?.should be_false
      end
    
    end
  
    describe "confirm" do
      
      context "in webservice mode" do
      
        before(:each) do
          @af.stub!(:apc).and_return(@approved_apc_response)
        end
    
        it "should call CAP once" do
          @af.approve(@valid_params)
          @af.should_receive(:cap).with({"Transacao" => "7777"}).once.and_return(@success_cap_response_webservice)
          @af.confirm({"Transacao" => "7777"})
        end
        
        context "when transaction was confirmed" do
          
          before(:each) do
            @af.stub!(:cap).once.and_return(@success_cap_response_webservice)
          end

          it "should store response from CAP" do
            @af.confirm(@valid_params)
            @af.instance_variable_get(:@cap_response).should == @success_cap_response_webservice
          end
      
          it "should store last response from CAP" do
            @af.confirm(@valid_params)
            @af.last_response.should == @success_cap_response_webservice
          end
      
          it "should clear error message" do
            @af.instance_variable_set(:@error_message, "Error Message")
            @af.confirm(@valid_params)
            @af.error_message.should be_nil
          end
            
          it "should return true" do
            @af.confirm(@valid_params).should be_true
          end
                
        end
        
        context "when transaction was not confirmed" do
          
          before(:each) do
            @af.stub!(:cap).once.and_return(@error_cap_response_webservice)
          end
          
          it "should return false" do
            @af.confirm(@valid_params).should be_false
          end
          
          it "should store error messages from response" do
            @af.confirm(@valid_params)
            @af.error_message.should == "Erro%20­%20Transa%E7%E3o%20a%20confirmar%20n%E3o%20encontrada%20ou %20jE1%20confirmada"
          end
          
        end
        
      end
      
      context "in cgi mode" do
      
        before(:each) do
          @af = AprovaFacil.new(@config_file_cgi)
          @af.stub!(:apc).and_return(@approved_apc_response)
        end
    
        it "should call CAP once" do
          @af.approve(@valid_params)
          @af.should_receive(:cap).with({"Transacao" => "7777"}).once.and_return(@success_cap_response_cgi)
          @af.confirm({"Transacao" => "7777"})
        end
        
        context "when transaction was confirmed" do
          
          before(:each) do
            @af.stub!(:cap).once.and_return(@success_cap_response_cgi)
          end

          it "should store response from CAP" do
            @af.confirm(@valid_params)
            @af.instance_variable_get(:@cap_response).should == @success_cap_response_cgi
          end
      
          it "should store last response from CAP" do
            @af.confirm(@valid_params)
            @af.last_response.should == @success_cap_response_cgi
          end
      
          it "should clear error message" do
            @af.instance_variable_set(:@error_message, "Error Message")
            @af.confirm(@valid_params)
            @af.error_message.should be_nil
          end
            
          it "should return true" do
            @af.confirm(@valid_params).should be_true
          end
                
        end
        
        context "when transaction was not confirmed" do
          
          before(:each) do
            @af.stub!(:cap).once.and_return(@error_cap_response_cgi)
          end
          
          it "should return false" do
            @af.confirm(@valid_params).should be_false
          end
          
          it "should store error messages from response" do
            @af.confirm(@valid_params)
            @af.error_message.should == "Erro%20­%20Transa%E7%E3o%20a%20confirmar%20n%E3o%20encontrada%20ou %20jE1%20confirmada"
          end
          
        end
        
      end
    
    end
  
    describe "confirmed?" do

      it "should raise exception if no CAP response" do
        lambda {
          @af.confirmed?
        }.should raise_exception("Call this method after confirm")
      end
      
      context "in webservice mode" do
      
        it "should return true if last CAP request was confirmed" do
          @af.instance_variable_set(:@cap_response, @success_cap_response_webservice)
          @af.confirmed?.should be_true
        end
      
        it "should return false if last CAP request was not confirmed" do
          @af.instance_variable_set(:@cap_response, @error_cap_response_webservice)
          @af.confirmed?.should be_false
        end
        
      end
      
      context "in cgi mode" do
        
        before(:each) do
          @af = AprovaFacil.new(@config_file_cgi)
        end
      
        it "should return true if last CAP request was confirmed" do
          @af.instance_variable_set(:@cap_response, @success_cap_response_cgi)
          @af.confirmed?.should be_true
        end
      
        it "should return false if last CAP request was not confirmed" do
          @af.instance_variable_set(:@cap_response, @error_cap_response_cgi)
          @af.confirmed?.should be_false
        end
        
      end
    
    end
  
    describe "cancel" do

      before(:each) do
        @af.stub!(:cap).and_return(@success_cap_response_cgi)
      end
      
      context "in webservice mode" do

        it "should call CAN once" do
          @af.should_receive(:can).with({"Transacao" => "7777"}).once.and_return(@cancelled_can_response)
          @af.cancel({"Transacao" => "7777"})
        end
    
        describe "when transaction was cancelled" do
      
          before(:each) do
            @af.stub!(:can).once.and_return(@cancelled_can_response)
          end

          it "should store response from CAP" do
            @af.cancel(@valid_params)
            @af.instance_variable_get(:@can_response).should == @cancelled_can_response
          end
    
          it "should store last response from CAP" do
            @af.cancel(@valid_params)
            @af.last_response.should == @cancelled_can_response
          end
    
          it "should clear error message if cancelled" do
            @af.instance_variable_set(:@error_message, "Error Message")
            @af.cancel(@valid_params)
            @af.error_message.should be_nil
          end
    
          it "should return true if transaction was cancelled" do
            @af.cancel(@valid_params).should be_true
          end

        end
    
        context "when transaction was marked to cancel" do
      
          before(:each) do
            @af.stub!(:can).once.and_return(@to_cancel_can_response)
          end

          it "should clear error message" do
            @af.instance_variable_set(:@error_message, "Error Message")
            @af.cancel(@valid_params)
            @af.error_message.should be_nil
          end

          it "should return true" do
            @af.cancel(@valid_params).should be_true
          end      
      
        end
    
        context "when transaction was not cancelled" do
      
          before(:each) do
            @af.stub!(:can).once.and_return(@error_can_response)
          end
      
          it "should return false" do
            @af.cancel(@valid_params).should be_false
          end
      
          it "should store error message from response" do
            @af.cancel(@valid_params)
            @af.error_message.should == @error_can_response["ResultadoSolicitacaoCancelamento"]
          end
      
      
        end
        
      end
      
      context "in cgi mode" do
        
        before(:each) do
          @af = AprovaFacil.new(@config_file_cgi)
        end

        it "should raise exception" do
          lambda {
            @af.cancel(@valid_params)
          }.should raise_exception("Method not available in cgi mode")
        end
        
      end
    
    end
  
    describe "cancelled?" do
    
      it "should raise exception if no CAN response" do
        lambda {
          @af.cancelled?
        }.should raise_exception("Call this method after cancel")
      end
      
      it "should return true if last CAN request was cancelled" do
        @af.instance_variable_set(:@can_response, @cancelled_can_response)
        @af.cancelled?.should be_true
      end
      
      it "should return false if last CAN request was not cancelled" do
        @af.instance_variable_set(:@can_response, @error_can_response)
        @af.cancelled?.should be_false
      end    

      it "should return false if last CAN request was marked to cancel" do
        @af.instance_variable_set(:@can_response, @to_cancel_can_response)
        @af.cancelled?.should be_false
      end    

    end

    describe "to_cancel?" do
    
      it "should raise exception if no CAN response" do
        lambda {
          @af.to_cancel?
        }.should raise_exception("Call this method after cancel")
      end
      
      it "should return true if last CAN request was cancelled" do
        @af.instance_variable_set(:@can_response, @cancelled_can_response)
        @af.to_cancel?.should be_false
      end
      
      it "should return false if last CAN request was not cancelled" do
        @af.instance_variable_set(:@can_response, @error_can_response)
        @af.to_cancel?.should be_false
      end    

      it "should return false if last CAN request was marked to cancel" do
        @af.instance_variable_set(:@can_response, @to_cancel_can_response)
        @af.to_cancel?.should be_true
      end    

    end

    describe "error?" do
    
      it "should return true if last request was not complete" do
        @af.instance_variable_set(:@error_message, "Error Message")
        @af.error?.should be_true
      end

      it "should return false if last request was complete" do
        @af.instance_variable_set(:@error_message, nil)
        @af.error?.should be_false
      end
    
    end
    
  end

  describe "do_post" do

    before(:all) do
      dirty_data_structure = File.expand_path(File.dirname(__FILE__) + '/fixtures/dirty_data_structure.xml')      
      f = File.new(dirty_data_structure, "r")
      @dirty_data_structure = f.read
      f.close
      
      FakeWeb.register_uri(:post, "http://teste.aprovafacil.com/cgi-bin/APFW/usuario/APC", :body => @dirty_data_structure, :status => ["200", "OK"])
      
      @url = "http://teste.aprovafacil.com/cgi-bin/APFW/usuario/APC"
      @params = {:q => 'just testing'}
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
