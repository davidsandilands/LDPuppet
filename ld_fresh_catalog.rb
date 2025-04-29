#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require 'ldclient-rb'
require 'facter'
require 'openssl'
require 'English'

# Puppet has information written into its certificate request signed by the CA
# this is the most commonly used information to classify nodes
# This is clearly lazily generated chatgpt code but I didn't want to go into the weeds of parsing the cert
def extract_cert_trusted_facts(certname = nil)
  certname ||= `/opt/puppetlabs/puppet/bin/puppet config print certname`.strip
  cert_path = "/etc/puppetlabs/puppet/ssl/certs/#{certname}.pem"
  raise "Certificate not found: #{cert_path}" unless File.exist?(cert_path)

  cert = OpenSSL::X509::Certificate.new(File.read(cert_path))
  trusted = {}

  # Get Common Name
  subject = cert.subject.to_a.find { |name, _, _| name == 'CN' }
  trusted['certname'] = subject[1] if subject

  # Map known Puppet trusted fact OIDs
  puppet_oids = {
    '1.3.6.1.4.1.34380.1.1.1' => 'pp_role',
    '1.3.6.1.4.1.34380.1.1.2' => 'pp_environment',
    '1.3.6.1.4.1.34380.1.1.3' => 'pp_hostname',
    '1.3.6.1.4.1.34380.1.1.4' => 'pp_domain',
    '1.3.6.1.4.1.34380.1.1.5' => 'pp_uuid',
    '1.3.6.1.4.1.34380.1.1.6' => 'pp_network',
    '1.3.6.1.4.1.34380.1.1.7' => 'pp_datacenter'
  }

  cert.extensions.each do |ext|
    if ext.oid == 'subjectAltName'
      trusted['sans'] = ext.value.split(',').map(&:strip)
    elsif puppet_oids.key?(ext.oid)
      # Only handle known Puppet trusted OIDs
      clean_value = ext.value.to_s
      # Clean step 1: Remove 'UTF8String: ' prefix
      clean_value.gsub!(/\AUTF8String: /, '')
      # Clean step 2: Remove non-printable characters (dots, control chars)
      clean_value.gsub!(/[^[:print:]]/, '')
      # Clean step 3: Remove leading dots and spaces
      clean_value.gsub!(/\A[.\s]+/, '')
      # Clean step 4: Strip trailing spaces
      clean_value.strip!
      trusted[puppet_oids[ext.oid]] = clean_value
    end
  end

  trusted
end

LD_SDK_KEY = ENV['LD_SDK_KEY'] || 'your-sdk-key-here'
FLAG_NAME = 'fresh-catalog'
# Pass in a certname to allow us to run multiple agents from only one VM
certname_arg = ARGV[0]

# Build context
facts = Facter.to_hash
trusted = extract_cert_trusted_facts(certname_arg)
context_key = trusted['certname'] || 'unknown-host'
ld_context = {
  kind: 'puppetnode',
  key: context_key,
  hostname: facts['hostname'],
  pp_role: trusted['pp_role'],
  pp_environment: trusted['pp_environment'],
  timestamp: Time.now.utc.iso8601
}

client = LaunchDarkly::LDClient.new(LD_SDK_KEY)

unless client.initialized?
  warn 'LaunchDarkly client not initialized'
  exit 1
end

use_fresh = client.variation(FLAG_NAME, ld_context, false)

# Run puppet
# Puppet can either contact its server and generate a new catalog or use the cached one the flag will determine which
result = nil
puts trusted['certname']
if use_fresh
  puts 'Running fresh catalog'
  result = system('/opt/puppetlabs/bin/puppet', 'agent', '-t', '--certname', trusted['certname'])
  event_type = case $CHILD_STATUS.exitstatus
               when 0
                 'puppet_no_change'
               when 2
                 'puppet_change'
               else
                 'puppet_error'
               end
else
  puts 'Running cached catalog'
  result = system('/opt/puppetlabs/bin/puppet', 'agent', '--usecacheonfailure', '--certname', trusted['certname'])
  event_type = 'puppet_cached'
end

# Send custom event
client.track(event_type, ld_context)

client.flush
client.close

exit result ? 0 : 1
