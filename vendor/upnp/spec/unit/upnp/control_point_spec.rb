require 'spec_helper'
require 'upnp/control_point'


describe UPnP::ControlPoint do
  subject do
    UPnP::ControlPoint.new(1)
  end

  describe "#ssdp_search_and_listen" do
    let(:notification) do
      double "notification"
    end

    let(:searcher) do
      s = double "UPnP::SSDP::Searcher"
      s.stub_chain(:discovery_responses, :subscribe).and_yield notification

      s
    end

    before do
      UPnP::SSDP.should_receive(:search).with("ssdp:all", {}).and_return searcher
      EM.stub(:add_periodic_timer)
    end

    after do
      EM.unstub(:add_periodic_timer)
    end

    it "creates a ControlPoint::Device for every discovery response" do
      EM.stub(:add_timer)
      subject.should_receive(:create_device).with(notification)
      subject.ssdp_search_and_listen("ssdp:all")
    end

    it "shuts down the searcher and starts the listener after the given response wait time" do
      EM.stub(:add_timer).and_yield
      subject.stub(:create_device)
      searcher.should_receive(:close_connection)
      subject.should_receive(:listen)
      subject.ssdp_search_and_listen("ssdp:all")
    end
  end
end
