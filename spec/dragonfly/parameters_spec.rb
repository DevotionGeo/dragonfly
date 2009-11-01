require File.dirname(__FILE__) + '/../spec_helper'

describe Dragonfly::Parameters do
  
  def standard_attributes
    {
      :uid => 'ahaha',
      :processing_method => :round,
      :mime_type => 'image/gif',
      :processing_options => {:radius => 5},
      :encoding => {:flumps_per_minute => 56}
    }
  end
  
  describe "initializing" do
    it "should allow initializing without a hash" do
      parameters = Dragonfly::Parameters.new
      parameters.uid.should be_nil
    end
    it "should allow initializing with a hash" do
      parameters = Dragonfly::Parameters.new(:uid => 'b')
      parameters.uid.should == 'b'
    end
    it "should raise an error if initialized with a bad hash key" do
      lambda{
        Dragonfly::Parameters.new(:fridge => 'cold')
      }.should raise_error(ArgumentError)
    end
  end
  
  describe "accessors" do
    before(:each) do
      @parameters = Dragonfly::Parameters.new
    end
    it "should give the accessors the correct defaults" do
      @parameters.uid.should be_nil
      @parameters.processing_method.should be_nil
      @parameters.mime_type.should be_nil
      @parameters.processing_options.should == {}
      @parameters.encoding.should == {}
    end
    it "should provide writers too" do
      @parameters.uid = 'hello'
      @parameters.uid.should == 'hello'
    end
  end
  
  describe "array style accessors" do
    before(:each) do
      @parameters = Dragonfly::Parameters.new(:uid => 'hello')
    end
    it "should be the same as calling the corresponding reader" do
      @parameters[:uid].should == @parameters.uid
    end
    it "should be the same as calling the corresponding writer" do
      @parameters[:uid] = 'goodbye'
      @parameters.uid.should == 'goodbye'
    end
  end
  
  describe "comparing" do
    before(:each) do
      @parameters1 = Dragonfly::Parameters.new(standard_attributes)
      @parameters2 = Dragonfly::Parameters.new(standard_attributes)      
    end
    it "should return true when two have all the same attributes" do
      @parameters1.should == @parameters2
    end
    %w(uid processing_method mime_type processing_options encoding).each do |attribute|
      it "should return false when #{attribute} is different" do
        @parameters2[attribute.to_sym] = 'fish'
        @parameters1.should_not == @parameters2
      end
    end
  end
  
  describe "to_hash" do
    it "should return the attributes as a hash" do
      parameters = Dragonfly::Parameters.new(standard_attributes)
      parameters.to_hash.should == standard_attributes
    end
  end
  
  describe "custom parameters classes" do
    
    before(:each) do
      @parameters_class = Class.new(Dragonfly::Parameters)
    end
    
    describe "when defaults are not set" do
      it "should return the standard defaults" do
        parameters = @parameters_class.new
        parameters.processing_method.should be_nil
        parameters.processing_options.should == {}
        parameters.mime_type.should be_nil
        parameters.encoding.should == {}
      end
    end
    
    describe "when defaults are set" do
      before(:each) do
        @parameters_class.configure do |c|
          c.default_processing_method = :resize
          c.default_processing_options = {:scale => '0.5'}
          c.default_mime_type = 'image/png'
          c.default_encoding = {:bit_rate => 24}
        end
      end
      it "should return the default if not set on parameters" do
        parameters = @parameters_class.new
        parameters.processing_method.should == :resize
        parameters.processing_options.should == {:scale => '0.5'}
        parameters.mime_type.should == 'image/png'
        parameters.encoding.should == {:bit_rate => 24}
      end
      it "should return the correct parameter if set" do
        parameters = @parameters_class.new(
          :processing_method => :yo,
          :processing_options => {:a => 'b'},
          :mime_type => 'text/plain',
          :encoding => {:ah => :arg}
        )
        parameters.processing_method.should == :yo
        parameters.processing_options.should == {:a => 'b'}
        parameters.mime_type.should == 'text/plain'
        parameters.encoding.should == {:ah => :arg}
      end
    end
    
  end
  
  describe "validate!" do
    before(:each) do
      @parameters = Dragonfly::Parameters.new(standard_attributes)
    end
    it "should not raise an error when parameters are ok" do
      @parameters.validate!
    end
    it "should raise an error when the uid is not set" do
      @parameters.uid = nil
      lambda{
        @parameters.validate!
      }.should raise_error(Dragonfly::Parameters::InvalidParameters)
    end
    it "should raise an error when the uid is not set" do
      @parameters.mime_type = nil
      lambda{
        @parameters.validate!
      }.should raise_error(Dragonfly::Parameters::InvalidParameters)
    end
    it "should not raise an error when other parameters aren't set" do
      parameters = Dragonfly::Parameters.new(:uid => 'asdf', :mime_type => 'image/jpeg')
      parameters.validate!
    end
  end
  
  describe "shortcuts" do
    
    before(:each) do
      @parameters_class = Class.new(Dragonfly::Parameters)
    end
    
    it "should allow for setting simple shortcuts" do
      attributes = {
        :processing_method => :duncan,
        :processing_options => {:bill => :gates},
        :mime_type => 'mama/mia',
        :encoding => {:doogie => :howser}
      }
      @parameters_class.add_shortcut(:doobie, attributes)
      @parameters_class.from_shortcut(:doobie).should == Dragonfly::Parameters.new(attributes)
    end
    
    it "should raise an error if the shortcut doesn't exist" do
      lambda{
        @parameters_class.from_shortcut(:idontexist)
      }.should raise_error(Dragonfly::Parameters::InvalidShortcut)
    end
    
    describe "block shortcuts" do
      
      before(:each) do
        @parameters_class.add_shortcut(/^hello.*$/, String) do |processing_method, mime_type, matches|
          {:processing_method => processing_method, :mime_type => mime_type}
        end
      end
      
      it "should allow for more complex shortcuts by using a block and matching args" do
        parameters = Dragonfly::Parameters.new(:processing_method => 'hellothere', :mime_type => 'image/tiff')
        @parameters_class.from_shortcut('hellothere', 'image/tiff').should == parameters
      end

      it "should raise an error if the shortcut doesn't match properly" do
        lambda{
          @parameters_class.from_shortcut('hellothere', :'image/tiff')
        }.should raise_error(Dragonfly::Parameters::InvalidShortcut)
      end
      
      it "should raise an error if the shortcut matches but has the wrong number of args" do
        lambda{
          @parameters_class.from_shortcut('hellothere', 'image/tiff', 'YO')
        }.should raise_error(Dragonfly::Parameters::InvalidShortcut)
      end

    end
    
    describe "single regexp shortcuts" do
      
      it "should yield regexp match data if the args is just one regexp" do
        @parameters_class.add_shortcut(/^hello(.*)$/) do |arg, match_data|
          {:processing_options => {:arg => arg, :match_data => match_data}}
        end
        processing_options = @parameters_class.from_shortcut('hellothere').processing_options
        processing_options[:arg].should == 'hellothere'
        processing_options[:match_data].should be_a(MatchData)
        processing_options[:match_data][1].should == 'there'
      end
      
    end
    
  end
  
  describe "unique_signature" do
    
    before(:each) do
      @parameters = Dragonfly::Parameters.new(standard_attributes)
      @parameters2 = Dragonfly::Parameters.new(standard_attributes)
    end
    
    it "should a unique identifier based on its attributes" do
      @parameters.unique_signature.should be_a(String)
      @parameters.unique_signature.length.should > 0
    end
    
    it "should be the same if the attributes are the same" do
      @parameters.unique_signature.should == @parameters2.unique_signature
    end
    
    it "should be different when the uid is changed" do
      @parameters2.uid = 'different yo'
      @parameters.unique_signature.should_not == @parameters2.unique_signature
    end
   
    it "should be different when the mime_type is changed" do
      @parameters2.mime_type = 'image/tiff'
      @parameters.unique_signature.should_not == @parameters2.unique_signature
    end
    
    it "should be different when the processing_method is changed" do
      @parameters2.processing_method = :doogie
      @parameters.unique_signature.should_not == @parameters2.unique_signature
    end
   
    it "should be different when the processing_options are changed" do
      @parameters2.processing_options[:slumdog] = 'millionaire'
      @parameters.unique_signature.should_not == @parameters2.unique_signature
    end
    
    it "should be different when the encoding options are changed" do
      @parameters2.encoding[:flumps_per_minute] = 50.3
      @parameters.unique_signature.should_not == @parameters2.unique_signature
    end

  end
  
end