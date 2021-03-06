module Intrigue
module Task
class NmapScan < BaseTask

  include Intrigue::Task::Dns

  def self.metadata
    {
      :name => "nmap_scan",
      :pretty_name => "Nmap Scan",
      :authors => ["jcran"],
      :description => "This task runs an nmap scan on the target host or domain.",
      :references => [],
      :type => "discovery",
      :passive => false,
      :allowed_types => ["DnsRecord", "IpAddress", "NetBlock"],
      :example_entities => [{"type" => "DnsRecord", "details" => {"name" => "intrigue.io"}}],
      :allowed_options => [],
      :created_types => [ "DnsRecord", "IpAddress", "NetworkService", "Uri" ]
    }
  end

  ## Default method, subclasses must override this
  def run
    super

    ###
    ### TODO SECURITY - more sanity checking on to_scan
    ###

    # Get range, or host
    to_scan = [_get_entity_name]
    opt_top_ports = _get_option("top_ports")

    _log "Scan list is: #{to_scan}, ports: #{opt_top_ports}"

    to_scan.each do |scan_item|

      ### SECURITY!
      #raise "INVALID INPUT: #{scan_item}" unless match_regex :ip_address, scan_item

      # Create a tempfile to store results
      temp_file = "#{Dir::tmpdir}/nmap_scan_#{rand(100000000)}.xml"

      # Check for IPv6
      nmap_options = ""
      nmap_options << "-6" if scan_item =~ /:/

      # shell out to nmap and run the scan
      _log "Scanning #{scan_item} and storing in #{temp_file}"
      _log "NMap options: #{nmap_options}"

      # shell out to nmap and run the scan
      nmap_string = "nmap #{scan_item} #{nmap_options} -sSUV -P0 -T5 -p 21,22,23,35,80,81,443,502,503,1883,2181,2222,2888,3389,3888,5000,5900,5901,6379,6380,6443,7001,8032,8050,8080,8081,8291,8443,8883,9001,9091,9092,9200,9201,9300,9301,11211,27017,27018,27019,U:161 -O --max-os-tries 2 -oX #{temp_file}"
      nmap_string = "sudo #{nmap_string}" unless Process.uid == 0

      _log "Starting Scan: #{nmap_string}"
      output = _unsafe_system(nmap_string)
      _log "Nmap Output:\n#{output}"

      # Gather the XML and parse
      _log "Parsing #{temp_file}"

      parser = Nmap::XML.new(temp_file)

      # Create entities for each discovered service
      parser.each_host do |host|
        _log "Handling nmap data for #{host.ip}"
        _log "Total ports: #{host.ports.count}"
        _log "Total open ports: #{host.each_port.select{|p| p.state == :open}.count}"

        # Handle the case of a netblock or domain - where we will need to create ip entity(s)
        if @entity.type_string == "NetBlock"
          # Only create if we've got ports to report.
          ip_entity = _create_entity("IpAddress", { "name" => host.ip } ) if host.ports.count > 0
        else
          ip_entity = @entity
        end

        ip_entity.set_detail("os", host.os.matches)

        # iterate through all ports
        host.ports.each do |port|
          if port.state == :open

            _create_network_service_entity(ip_entity,
              port.number,
              "#{port.protocol}",
              { "nmap_details" => {
                  "protocol" => "#{port.service.protocol}",
                  "ssl" => "#{port.service.ssl?}",
                  "product" => "#{port.service.product}",
                  "version" => "#{port.service.version}",
                  "extra_info" => "#{port.service.extra_info}",
                  "hostname" => "#{port.service.hostname}",
                  "os_type" => "#{port.service.os_type}",
                  "device_type" => "#{port.service.device_type}",
                  "fingerprint_method" => "#{port.service.fingerprint_method}",
                  "fingerprint" => "#{port.service.fingerprint}",
                  "confidence" => "#{port.service.confidence}"
              }}
             )

          end # end if port.state == :open
        end # end ports
      end # end parser

      # Clean up!
      parser = nil

      begin
        File.delete(temp_file)
      rescue Errno::EPERM
        _log_error "Unable to delete file"
      end

    end
  end

  def check_external_dependencies
    # Check to see if nmap is in the path, and raise an error if not
    return false unless _unsafe_system("sudo nmap") =~ /http:\/\/nmap.org/
  true
  end

end
end
end
