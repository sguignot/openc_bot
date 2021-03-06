# encoding: UTF-8
require_relative '../../spec_helper'
require 'openc_bot'
require 'openc_bot/helpers/register_methods'

module ModuleThatIncludesRegisterMethods
  extend OpencBot
  extend OpencBot::Helpers::RegisterMethods
  PRIMARY_KEY_NAME = :custom_uid
  SCHEMA_NAME = 'company-schema'
end

module ModuleWithNoCustomPrimaryKey
  extend OpencBot
  extend OpencBot::Helpers::RegisterMethods
end

describe 'a module that includes RegisterMethods' do

  before do
    ModuleThatIncludesRegisterMethods.stub(:sqlite_magic_connection).
                                      and_return(test_database_connection)
  end

  after do
    remove_test_database
  end

  describe "#datum_exists?" do
    before do
      ModuleThatIncludesRegisterMethods.stub(:select).and_return([])

    end

    it "should select_data from database" do
      expected_sql_query = "ocdata.custom_uid FROM ocdata WHERE custom_uid = ? LIMIT 1"
      ModuleThatIncludesRegisterMethods.should_receive(:select).with(expected_sql_query, '4567').and_return([])
      ModuleThatIncludesRegisterMethods.datum_exists?('4567')
    end

    it "should return true if result returned" do
      ModuleThatIncludesRegisterMethods.stub(:select).and_return([{'custom_uid' => '4567'}])

      ModuleThatIncludesRegisterMethods.datum_exists?('4567').should be true
    end

    it "should return false if result returned" do
      ModuleThatIncludesRegisterMethods.datum_exists?('4567').should be false
    end
  end

  describe "#export_data" do
    before do
      ModuleThatIncludesRegisterMethods.stub(:select).and_return([])

    end

    it "should select_data from database" do
      expected_sql_query = "ocdata.* from ocdata"
      ModuleThatIncludesRegisterMethods.should_receive(:select).with(expected_sql_query).and_return([])
      ModuleThatIncludesRegisterMethods.export_data
    end

    it "should yield rows that have been passed to post_process" do
      datum = {'food' => 'tofu'}
      ModuleThatIncludesRegisterMethods.stub(:select).and_return([datum])
      ModuleThatIncludesRegisterMethods.should_receive(:post_process).with(datum, true).and_return(datum)
      ModuleThatIncludesRegisterMethods.export_data{|x|}
    end
  end


  describe '#primary_key_name' do
    it 'should return :uid if PRIMARY_KEY_NAME not set' do
      ModuleWithNoCustomPrimaryKey.send(:primary_key_name).should == :uid
    end

    it 'should return value if PRIMARY_KEY_NAME set' do
      ModuleThatIncludesRegisterMethods.send(:primary_key_name).should == :custom_uid
    end
  end

  describe "#use_alpha_search" do
    context 'and no USE_ALPHA_SEARCH constant' do
      it "should not return true" do
        ModuleThatIncludesRegisterMethods.use_alpha_search.should_not be true
      end
    end

    context 'and USE_ALPHA_SEARCH constant set' do
      it "should return USE_ALPHA_SEARCH" do
        stub_const("ModuleThatIncludesRegisterMethods::USE_ALPHA_SEARCH", true)
        ModuleThatIncludesRegisterMethods.use_alpha_search.should be true
      end
    end
  end

  describe "#schema_name" do
    context 'and no SCHEMA_NAME constant' do
      it "should return nil" do
        ModuleWithNoCustomPrimaryKey.schema_name.should be_nil
      end
    end

    context 'and SCHEMA_NAME constant set' do
      it "should return SCHEMA_NAME" do
        ModuleThatIncludesRegisterMethods.schema_name.should == 'company-schema'
      end
    end
  end

  describe "#update_data" do
    before do
      ModuleThatIncludesRegisterMethods.stub(:fetch_data_via_incremental_search)
      ModuleThatIncludesRegisterMethods.stub(:update_stale)
    end

    it "should get new records via incremental search" do
      ModuleThatIncludesRegisterMethods.should_not_receive(:fetch_data_via_alpha_search)
      ModuleThatIncludesRegisterMethods.should_receive(:fetch_data_via_incremental_search)
      ModuleThatIncludesRegisterMethods.update_data
    end

    it "should get new records via alpha search if use_alpha_search" do
      ModuleThatIncludesRegisterMethods.should_receive(:use_alpha_search).and_return(true)
      ModuleThatIncludesRegisterMethods.should_not_receive(:fetch_data_via_incremental_search)
      ModuleThatIncludesRegisterMethods.should_receive(:fetch_data_via_alpha_search)
      ModuleThatIncludesRegisterMethods.update_data
    end

    it "should update stale records" do
      ModuleThatIncludesRegisterMethods.should_receive(:update_stale)
      ModuleThatIncludesRegisterMethods.update_data
    end

    it "should save run report" do
      ModuleThatIncludesRegisterMethods.should_receive(:save_run_report).with(:status => 'success')
      ModuleThatIncludesRegisterMethods.update_data
    end

    it "should not raise error if passed options" do
      lambda { ModuleThatIncludesRegisterMethods.update_data }.should_not raise_error
    end
  end

  describe "#update_stale" do
    it "should get uids of stale entries" do
      ModuleThatIncludesRegisterMethods.should_receive(:stale_entry_uids)
      ModuleThatIncludesRegisterMethods.update_stale
    end

    it "should update_datum for each entry yielded by stale_entries" do
      ModuleThatIncludesRegisterMethods.stub(:stale_entry_uids).and_yield('234').and_yield('666').and_yield('876')
      ModuleThatIncludesRegisterMethods.should_receive(:update_datum).with('234')
      ModuleThatIncludesRegisterMethods.should_receive(:update_datum).with('666')
      ModuleThatIncludesRegisterMethods.should_receive(:update_datum).with('876')
      ModuleThatIncludesRegisterMethods.update_stale
    end

    context "and limit passed in" do
      it "should pass on limit to #stale_entries" do
        ModuleThatIncludesRegisterMethods.should_receive(:stale_entry_uids).with(42)
        ModuleThatIncludesRegisterMethods.update_stale(42)
      end
    end
  end

  describe "#stale_entry_uids" do
    before do
      ModuleThatIncludesRegisterMethods.save_data([:custom_uid], :custom_uid => '99999')
      ModuleThatIncludesRegisterMethods.save_data([:custom_uid], :custom_uid => 'A094567')
    end

    it "should get entries which have not been retrieved or are more than 1 month old" do
      ModuleThatIncludesRegisterMethods.save_data([:custom_uid], :custom_uid => '5234888', :retrieved_at => (Date.today-40).to_time)
      ModuleThatIncludesRegisterMethods.save_data([:custom_uid], :custom_uid => '9234567', :retrieved_at => (Date.today-2).to_time)

      expect {|b| ModuleThatIncludesRegisterMethods.stale_entry_uids(&b)}.to yield_successive_args('99999', 'A094567', '5234888')
    end

    context "and no retrieved_at column" do
      it "should not raise error" do
        lambda { ModuleThatIncludesRegisterMethods.stale_entry_uids {} }.should_not raise_error
      end

      it "should create retrieved_at column" do
        ModuleThatIncludesRegisterMethods.stale_entry_uids {}
        ModuleThatIncludesRegisterMethods.select('* from ocdata').first.keys.should include('retrieved_at')
      end

      it "should retry" do
        expect {|b| ModuleThatIncludesRegisterMethods.stale_entry_uids(&b)}.to yield_successive_args('99999','A094567')
      end
    end
  end

  describe '#prepare_and_save_data' do
    before do
      @params = {:name => 'Foo Inc', :custom_uid => '12345', :foo => ['bar','baz'], :foo2 => {:bar => 'baz'}}
    end

    it "should insert_or_update data using primary_key" do
      ModuleThatIncludesRegisterMethods.should_receive(:insert_or_update).with([:custom_uid], anything)
      ModuleThatIncludesRegisterMethods.prepare_and_save_data(@params)
    end

    it "should save basic data" do
      ModuleThatIncludesRegisterMethods.should_receive(:insert_or_update).with(anything, hash_including(:name => 'Foo Inc', :custom_uid => '12345'))
      ModuleThatIncludesRegisterMethods.prepare_and_save_data(@params)
    end

    it "should convert arrays and hashes to json" do
      ModuleThatIncludesRegisterMethods.should_receive(:insert_or_update).with(anything, hash_including(:foo => ['bar','baz'].to_json, :foo2 => {:bar => 'baz'}.to_json))
      ModuleThatIncludesRegisterMethods.prepare_and_save_data(@params)
    end

    it "should convert time and datetimes to iso601 version" do
      some_date = Date.parse('2012-04-23')
      some_time = Time.now
      ModuleThatIncludesRegisterMethods.should_receive(:insert_or_update).with(anything, hash_including(:some_date => some_date.iso8601, :some_time => some_time.iso8601))
      ModuleThatIncludesRegisterMethods.prepare_and_save_data(@params.merge(:some_date => some_date, :some_time => some_time))
    end

    it "should not change original params" do
      dup_params = Marshal.load( Marshal.dump(@params) )
      ModuleThatIncludesRegisterMethods.prepare_and_save_data(@params)
      @params.should == dup_params
    end

    it "should return true" do
      ModuleThatIncludesRegisterMethods.prepare_and_save_data(@params).should be_truthy
    end

    context 'and SQLite3::BusyException raised' do
      it 'should retry up to 3 times' do
        ModuleThatIncludesRegisterMethods.should_receive(:insert_or_update).exactly(4).times.and_raise(SQLite3::BusyException)
        lambda { ModuleThatIncludesRegisterMethods.prepare_and_save_data(@params) }.should raise_error(SQLite3::BusyException)
      end
      it 'should not raise error if successful before limit' do
        ModuleThatIncludesRegisterMethods.should_receive(:insert_or_update).exactly(3).times.ordered.and_raise(SQLite3::BusyException)
        ModuleThatIncludesRegisterMethods.should_receive(:insert_or_update).ordered
        lambda { ModuleThatIncludesRegisterMethods.prepare_and_save_data(@params) }.should_not raise_error
      end
    end

  end


  describe "#update_datum for uid" do
    before do
      @dummy_time = Time.now
      @uid = '23456'
      Time.stub(:now).and_return(@dummy_time)
      @fetch_datum_response = 'some really useful data'
      # @processed_data = ModuleThatIncludesRegisterMethods.process_datum(@fetch_datum_response)
      @processed_data = {:foo => 'bar'}
      ModuleThatIncludesRegisterMethods.stub(:fetch_datum).and_return(@fetch_datum_response)
      ModuleThatIncludesRegisterMethods.stub(:process_datum).and_return(@processed_data)
      @processed_data_with_retrieved_at_and_uid = @processed_data.merge(:custom_uid => @uid, :retrieved_at => @dummy_time)
      ModuleThatIncludesRegisterMethods.stub(:save_data!)
      ModuleThatIncludesRegisterMethods.stub(:validate_datum).and_return([])
      ModuleThatIncludesRegisterMethods.stub(:insert_or_update)
    end

    it "should fetch_datum for company number" do
      ModuleThatIncludesRegisterMethods.should_receive(:fetch_datum).with(@uid).and_return(@fetch_datum_response)
      ModuleThatIncludesRegisterMethods.update_datum(@uid)
    end

    context "and nothing returned from fetch_datum" do
      before do
        ModuleThatIncludesRegisterMethods.stub(:fetch_datum) # => nil
      end

      it "should not process_datum" do
        ModuleThatIncludesRegisterMethods.should_not_receive(:process_datum)
        ModuleThatIncludesRegisterMethods.update_datum(@uid)
      end

      it "should not save data" do
        ModuleThatIncludesRegisterMethods.should_not_receive(:save_data!)
        ModuleThatIncludesRegisterMethods.update_datum(@uid)
      end

      it "should return nil" do
        ModuleThatIncludesRegisterMethods.update_datum(@uid).should be_nil
      end

    end

    context 'and data returned from fetch_datum' do
      it "should process_datum returned from fetching" do
        ModuleThatIncludesRegisterMethods.should_receive(:process_datum).with(@fetch_datum_response)
        ModuleThatIncludesRegisterMethods.update_datum(@uid)
      end

      it "should validate processed data" do
        ModuleThatIncludesRegisterMethods.should_receive(:validate_datum).with(hash_including(@processed_data_with_retrieved_at_and_uid)).and_return([])
        ModuleThatIncludesRegisterMethods.update_datum(@uid)
      end

      it "should prepare processed data for saving including timestamp" do
        ModuleThatIncludesRegisterMethods.should_receive(:prepare_for_saving).with(hash_including(@processed_data_with_retrieved_at_and_uid)).and_return({})
        ModuleThatIncludesRegisterMethods.update_datum(@uid)
      end

      it "should include data in data to be prepared for saving" do
        ModuleThatIncludesRegisterMethods.should_receive(:prepare_for_saving).with(hash_including(:data => @fetch_datum_response)).and_return({})
        ModuleThatIncludesRegisterMethods.update_datum(@uid)
      end

      it "should use supplied retrieved_at in preference to default" do
        different_time = (Date.today-3).iso8601
        ModuleThatIncludesRegisterMethods.stub(:process_datum).
                                          and_return(@processed_data.merge(:retrieved_at => different_time))
        ModuleThatIncludesRegisterMethods.should_receive(:prepare_for_saving).
                                          with(hash_including(:retrieved_at => different_time)).and_return({})
        ModuleThatIncludesRegisterMethods.update_datum(@uid)
      end

      it "should save prepared_data" do
        ModuleThatIncludesRegisterMethods.stub(:prepare_for_saving).and_return({:foo => 'some prepared data'})

        ModuleThatIncludesRegisterMethods.should_receive(:insert_or_update).with([:custom_uid], hash_including(:foo => 'some prepared data'))
        ModuleThatIncludesRegisterMethods.update_datum(@uid)
      end

      it "should return data including uid" do
        ModuleThatIncludesRegisterMethods.update_datum(@uid).should == @processed_data_with_retrieved_at_and_uid
      end

      it "should not output jsonified processed data by default" do
        ModuleThatIncludesRegisterMethods.should_not_receive(:puts).with(@processed_data_with_retrieved_at_and_uid.to_json)
        ModuleThatIncludesRegisterMethods.update_datum(@uid)
      end

      RSpec::Matchers.define :jsonified_output do |expected_output|
        match do |actual|
          parsed_actual_json = JSON.parse(actual)
          parsed_actual_json.except('retrieved_at') == expected_output.except('retrieved_at') and
          parsed_actual_json['retrieved_at'].to_time.to_s == expected_output['retrieved_at'].to_time.to_s

        end
      end

      it "should output jsonified processed data to STDOUT if passed true as second argument" do
        expected_output = @processed_data_with_retrieved_at_and_uid.
          merge(:retrieved_at => @processed_data_with_retrieved_at_and_uid[:retrieved_at].iso8601).stringify_keys
        ModuleThatIncludesRegisterMethods.should_receive(:puts).with(jsonified_output(expected_output))
        ModuleThatIncludesRegisterMethods.update_datum(@uid, true)
      end


      RSpec::Matchers.define :jsonified_error_details_including do |expected_output|
        match { |actual| error_details = JSON.parse(actual)['error']; expected_output.all? { |k,v| error_details[k] == v } }
      end

      context "and exception raised" do
        before do
          ModuleThatIncludesRegisterMethods.stub(:process_datum).and_raise('something went wrong')
        end

        it "should output error message as JSON if true passes as second argument" do
          ModuleThatIncludesRegisterMethods.should_receive(:puts).with(jsonified_error_details_including('message' => 'something went wrong', 'klass' => 'RuntimeError'))
          # ModuleThatIncludesRegisterMethods.should_receive(:puts).
          #                                   with{ |error_output| error_hash = JSON.parse(error_output); error_hash['error']['message'].should == 'something went wrong' }
          ModuleThatIncludesRegisterMethods.update_datum(@uid, true)
        end

        it "should raise exception if true not passed as second argument" do
          lambda { ModuleThatIncludesRegisterMethods.update_datum(@uid)}.should raise_error("something went wrong updating entry with uid: #{@uid}")
        end
      end

      context 'and process_datum returns nil' do
        before do
          ModuleThatIncludesRegisterMethods.stub(:process_datum).and_return(nil)
        end

        it 'should return nil' do
          ModuleThatIncludesRegisterMethods.update_datum(@uid)
        end

        it 'should not validate_datum' do
          ModuleThatIncludesRegisterMethods.should_not_receive(:validate_datum)
          ModuleThatIncludesRegisterMethods.update_datum(@uid)
        end

      end
    end
  end

  describe '#registry_url for uid' do
    it 'should get computed_registry_url' do
      ModuleThatIncludesRegisterMethods.should_receive(:computed_registry_url).with('338811').and_return('http://some.url')
      ModuleThatIncludesRegisterMethods.registry_url('338811').should == 'http://some.url'
    end

    context "and computed_registry_url returns nil" do
      it 'should get registry_url_from_db' do
        ModuleThatIncludesRegisterMethods.stub(:computed_registry_url)
        ModuleThatIncludesRegisterMethods.should_receive(:registry_url_from_db).with('338811').and_return('http://another.url')
        ModuleThatIncludesRegisterMethods.registry_url('338811').should == 'http://another.url'
      end
    end
  end

  describe "#fetch_registry_page for company_number" do
    before do
      @dummy_client = double('http_client', :get_content => nil)
      ModuleThatIncludesRegisterMethods.stub(:_client).and_return(@dummy_client)
      ModuleThatIncludesRegisterMethods.stub(:registry_url).and_return('http://some.registry.url')
    end

    it "should GET registry_page for registry_url for company_number" do
      ModuleThatIncludesRegisterMethods.should_receive(:registry_url).
                                        with('76543').and_return('http://some.registry.url')
      @dummy_client.should_receive(:get_content).with('http://some.registry.url')
      ModuleThatIncludesRegisterMethods.fetch_registry_page('76543')
    end

    it "should return result of GETing registry_page" do
      @dummy_client.stub(:get_content).and_return(:registry_page_html)
      ModuleThatIncludesRegisterMethods.fetch_registry_page('76543').should == :registry_page_html
    end
  end

  describe "#validate_datum" do
    before do
      @valid_params = {:name => 'Foo Inc', :company_number => '12345', :jurisdiction_code => 'ie'}
    end

    it "should check json version of datum against given schema" do
      JSON::Validator.should_receive(:fully_validate).with('company-schema.json', @valid_params.to_json, anything)
      ModuleThatIncludesRegisterMethods.validate_datum(@valid_params)
    end

    context "and datum is valid" do
      it "should return empty array" do
        ModuleThatIncludesRegisterMethods.validate_datum(@valid_params).should == []
      end
    end

    context "and datum is not valid" do
      it "should return errors" do
        result = ModuleThatIncludesRegisterMethods.validate_datum({:name => 'Foo Inc', :jurisdiction_code => 'ie'})
        result.should be_kind_of Array
        result.size.should == 1
        result.first[:failed_attribute].should == "Required"
        result.first[:message].should match 'company_number'
      end
    end
  end

  describe "save_entity" do
    before do
      @params = {:name => 'Foo Inc', :custom_uid => '12345', :data => {:foo => 'bar'}}
    end

    it "should validate entity data" do
      ModuleThatIncludesRegisterMethods.should_receive(:validate_datum).with(@params.except(:data)).and_return([])
      ModuleThatIncludesRegisterMethods.save_entity(@params)
    end

    context "and entity_data is valid (excluding :data)" do
      before do
        ModuleThatIncludesRegisterMethods.stub(:validate_datum).and_return([])
      end

      it "should prepare and save data" do
        ModuleThatIncludesRegisterMethods.should_receive(:prepare_and_save_data).with(@params)
        ModuleThatIncludesRegisterMethods.save_entity(@params)
      end

      it "should return true" do
        ModuleThatIncludesRegisterMethods.save_entity(@params).should be_truthy
      end
    end

    context "and entity_data is not valid" do
      before do
        ModuleThatIncludesRegisterMethods.stub(:validate_datum).and_return([{:message=>'Not valid'}])
      end

      it "should not prepare and save data" do
        ModuleThatIncludesRegisterMethods.should_not_receive(:prepare_and_save_data)
        ModuleThatIncludesRegisterMethods.save_entity(@params)
      end

      it "should not return true" do
        ModuleThatIncludesRegisterMethods.save_entity(@params).should_not be true
      end
    end
  end

  describe "save_entity!" do
    before do
      @params = {:name => 'Foo Inc', :custom_uid => '12345', :data => {:foo => 'bar'}}
    end

    it "should validate entity data (excluding :data)" do
      ModuleThatIncludesRegisterMethods.should_receive(:validate_datum).with(@params.except(:data)).and_return([])
      ModuleThatIncludesRegisterMethods.save_entity!(@params)
    end

    context "and entity_data is valid" do
      before do
        ModuleThatIncludesRegisterMethods.stub(:validate_datum).and_return([])
      end

      it "should prepare and save data" do
        ModuleThatIncludesRegisterMethods.should_receive(:prepare_and_save_data).with(@params)
        ModuleThatIncludesRegisterMethods.save_entity!(@params)
      end

      it "should return true" do
        ModuleThatIncludesRegisterMethods.save_entity!(@params).should be_truthy
      end
    end

    context "and entity_data is not valid" do
      before do
        ModuleThatIncludesRegisterMethods.stub(:validate_datum).and_return([{:message=>'Not valid'}])
      end

      it "should not prepare and save data" do
        ModuleThatIncludesRegisterMethods.should_not_receive(:prepare_and_save_data)
        lambda {ModuleThatIncludesRegisterMethods.save_entity!(@params)}
      end

      it "should raise exception" do
        lambda {ModuleThatIncludesRegisterMethods.save_entity!(@params)}.should raise_error(OpencBot::RecordInvalid)
      end
    end
  end

  describe '#post_process' do
    before do
      @unprocessed_data = { :name => 'Foo Corp',
        :company_number => '12345',
        :serialised_field_1 => "[\"foo\",\"bar\"]",
        :serialised_field_2 => "[{\"position\":\"gestor\",\"name\":\"JOSE MANUEL REYES R.\",\"other_attributes\":{\"foo\":\"bar\"}}]",
        :serialised_field_3 => "{\"foo\":\"bar\"}",
        :serialised_field_4 => "[]",
        :serialised_field_5 => "{}",
        :serialised_field_6 => nil,
      }
    end

    context 'in general' do
      before do
        @processed_data = ModuleThatIncludesRegisterMethods.post_process(@unprocessed_data)
      end

      it 'should include non-serialised fields' do
        @processed_data[:name].should == @unprocessed_data[:name]
        @processed_data[:company_number].should == @unprocessed_data[:company_number]
      end

      it 'should deserialize fields' do
        @processed_data[:serialised_field_1].should == ['foo','bar']
        @processed_data[:serialised_field_3].should == {'foo' => 'bar'}
        @processed_data[:serialised_field_4].should == []
        @processed_data[:serialised_field_5].should == {}
      end

      it 'should deserialize nested fields correctly' do
        @processed_data[:serialised_field_2].first[:position].should == "gestor"
        @processed_data[:serialised_field_2].first[:other_attributes][:foo].should == "bar"
      end

      it 'should not do anything with null value' do
        @processed_data[:serialised_field_6].should be_nil
        @processed_data.has_key?(:serialised_field_6).should be true
      end
    end

    context 'with `skip_nulls` argument as true' do
      before do
        @processed_data = ModuleThatIncludesRegisterMethods.post_process(@unprocessed_data, true)
      end

      it 'should remove value from result' do
        @processed_data.has_key?(:serialised_field_6).should be false
      end
    end


    context "and there is generic :data field" do
      it "should not include it" do
        ModuleThatIncludesRegisterMethods.post_process(@unprocessed_data.merge(:data => 'something else'))[:data].should be_nil
        ModuleThatIncludesRegisterMethods.post_process(@unprocessed_data.merge(:data => "{\"bar\":\"baz\"}"))[:data].should be_nil
      end
    end
  end

end
