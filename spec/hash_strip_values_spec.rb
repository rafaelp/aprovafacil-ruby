# -*- encoding : utf-8 -*-
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Hash" do

  describe "strip_values!" do
    
    it 'should recurse and strip hash values' do
        hash = { :x => 1, :c => ' s ', :a => [' an ', ' array '], :h => { :nested => ' hash ' } }
        stripped = { :x => 1, :c =>  's',  :a => [ 'an',   'array' ], :h => { :nested =>  'hash' } }
        hash.strip_values!.should == stripped
      end

    it 'should not raise an exception if the hash contains an unhandled type' do
      lambda {
        { :e => 1 }.strip_values!
      }.should_not raise_error(ArgumentError)
    end

  end

end