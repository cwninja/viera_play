require "nokogiri"
require "viera_play/time_stamp"
module VieraPlay
  class TV
    def initialize(control_url)
      @soap_client = Soapy.new(
        :endpoint => control_url,
        :namespace => "urn:schemas-upnp-org:service:AVTransport:1",
        :default_request_args => {"InstanceID" => "0"}
      )
    end

    def stop
      send_command("Stop")
    end

    def toggle_pause
      if get_transport_info.playing?
        send_command("Pause")
      else
        play
      end
    end
    alias pause toggle_pause

    def play
      send_command("Play", "Speed" => "1")
    end

    def seek_by(ammount)
      info = get_position_info
      seek_to(info.position + ammount)
    end

    def seek_to(position)
      target = TimeStamp.new(position)
      send_command(
        "Seek",
        "Unit" => 'REL_TIME',
        "Target" => target
      )
    end

    def play_uri(uri)
      stop
      set_media_uri(uri)
      play
    end

    class SOAPInfo
      def initialize(xml)
        @doc = Nokogiri::XML(xml)
      end

    protected
      def extract_content(result_set)
        result_set.map(&:content).first
      end

      def extract_css(css)
        extract_content( @doc.css( css ) )
      end
    end

    class TransportInfo < SOAPInfo
      def playing?
        current_transport_state == 'PLAYING'
      end

      def paused?
        current_transport_state == 'PAUSED_PLAYBACK'
      end

      def stopped?
        current_transport_state == 'STOPPED'
      end

    protected
      def current_transport_state
        @current_transport_state ||= extract_css('CurrentTransportState')
      end
    end

    class PositionInfo < SOAPInfo
      def position
        TimeStamp.parse( extract_content( @doc.css( 'RelTime' ) ) )
      end

      def url
        extract_content( @doc.css( 'TrackURI' ) )
      end

      def duration
        TimeStamp.parse( extract_content( @doc.css( 'TrackDuration' ) ) )
      end

      def track
        sub_doc = extract_content(@doc.css('TrackMetaData'))
        parsed_subdoc = Nokogiri::XML(sub_doc)
        titles = parsed_subdoc.xpath(
          '//dc:title',
          'dc' => 'http://purl.org/dc/elements/1.1/'
        )
        extract_content(titles).to_s
      end

    end

    # Gets playback status information from the host. Returns a PositionInfo
    # instance.
    def get_position_info
      response = send_command("GetPositionInfo")
      PositionInfo.new response.body
    end

    def get_transport_info
      response = send_command("GetTransportInfo")
      TransportInfo.new response.body
    end

  private
    attr_reader :soap_client

    def set_media_uri(uri)
      send_command(
        "SetAVTransportURI",
        "CurrentURI" => uri,
        "CurrentURIMetaData" => ""
      )
    end

    def send_command(command, args={})
      soap_client.send_command(command, args)
    end
  end
end
