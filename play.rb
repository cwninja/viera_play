#!/usr/bin/ruby

require "webrick"
require "socket"

PORT = 8888

FORMATS = {
  ["mkv", "mp4", "wmv", "avi", "mov"] => "video/x-msvideo",
  ["mp3"] => "audio/mpeg"
}

TV_CONTROL_URL = "http://192.168.0.16:55000/dmr/control_2"

def local_ip
  UDPSocket.open do |s|
    s.connect '8.8.8.8', 1
    s.addr.last
  end
end

url_to_play = "http://#{local_ip}:#{PORT}/"

mime_types = WEBrick::HTTPUtils::DefaultMimeTypes
FORMATS.each do |file_types, mime_type|
  file_types.each do |file_type|
    mime_types.store file_type, mime_type
  end
end

class FileServlet < WEBrick::HTTPServlet::DefaultFileHandler
  # Serves the given file_path no matter what is asked for
  def initialize(server, file_path)
    super(server, "/tmp")
    @local_path = file_path
  end
end

file_path = ARGV.first
server = WEBrick::HTTPServer.new(:Port => PORT, :MimeTypes => mime_types)
server.mount("/", FileServlet, file_path)

class TV
  def initialize(control_url)
    @control_url = control_url
  end

  def stop
    post(
      control_url,
      {
        "SOAPACTION" => '"urn:schemas-upnp-org:service:AVTransport:1#Stop"',
        "Content-type" => "text/xml"
      },
      soap_body(
        "Stop",
        {
          "InstanceID" => "0"
        }
      )
    )
  end

  def play
    post(
      control_url,
      {
        "SOAPACTION" => '"urn:schemas-upnp-org:service:AVTransport:1#Play"',
        "Content-type" => "text/xml"
      },
      soap_body(
        "Play",
        {
          "InstanceID" => "0",
          "Speed" => "1"
        }
      )
    )
  end

  def set_media_uri(uri)
    post(
      control_url,
      {
        "SOAPACTION" => '"urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI"',
        "Content-type" => "text/xml"
      },
      soap_body(
        "SetAVTransportURI",
        {
          "InstanceID" => "0",
          "CurrentURI" => uri,
          "CurrentURIMetaData" => ""
        }
      )
    )
  end

private
  attr_reader :control_url

  def post(url, headers, data)
    args = headers.map { |key, value| ["-H", "'#{key}: #{value}'"] }.flatten
    args << "-X"
    args << "POST"
    args << "-d"
    args << "'#{data}'"
    args << url
    system("curl " + args.join(" "))
  end

  def soap_body(command, args)
    xml_args = args.map{ |key, value| "<#{key}>#{value}</#{key}>" }.join
    %Q{<?xml version="1.0"?>
      <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
        s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
        <s:Body>
          <u:#{command} xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
            #{xml_args}
          </u:#{command}>
        </s:Body>
      </s:Envelope>}
  end
end

tv = TV.new(TV_CONTROL_URL)

trap 'INT' do
  tv.stop
  server.shutdown
end

pid = Process.fork do
  server.start
end

tv.stop
tv.set_media_uri(url_to_play)
tv.play

Process.wait(pid)
