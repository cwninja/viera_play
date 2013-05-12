require 'upnp/ssdp'
require 'nokogiri'
require 'open-uri'
require 'uri'

UPnP.log=false

class VieraPlay::Scanner
  def self.services
    @instance ||= new
    @instance.services
  end

  def services
    services = UPnP::SSDP.search(service_type)
    locations = services.map{|v| v[:location] }.uniq
    locations.inject(Hash.new){ |acc, location|
      acc.merge(fetch_and_parse_service_description(location))
    }
  end

protected

  def service_type
    'urn:schemas-upnp-org:service:AVTransport:1'
  end

  def fetch_and_parse_service_description(service_description_url)
    Nokogiri::XML(open(service_description_url))
    services = doc.css('service')
    rendering_controller_services = services.select{|service|
      service.css('serviceType').text == service_type
    }
    rendering_controller_services.map{|service|
      control_path = service.css('controlURL').text
      control_url = URI.join(service_description_url, control_path)
      { doc.css('friendlyName').text => control_url }
    }
  end
end
