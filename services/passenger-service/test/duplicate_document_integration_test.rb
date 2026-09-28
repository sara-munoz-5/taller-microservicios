require 'minitest/autorun'
require 'securerandom'
require_relative '../lib/passenger_service_impl'

# Two simultaneous registrations with the same document (double click, two
# tabs) must create exactly one passenger.
class DuplicateDocumentIntegrationTest < Minitest::Test
  def test_concurrent_registrations_create_one_passenger
    service = PassengerServiceImpl.new
    document = "DUP#{SecureRandom.hex(8)}"
    request = Aeroreserva::V1::CreatePassengerRequest.new(
      document_type: 'CC', document_number: document, full_name: 'Prueba Duplicado', email: 'dup@example.test')
    results = Array.new(5) do
      Thread.new do
        service.create_passenger(request, nil).id
      rescue GRPC::AlreadyExists
        :duplicate
      end
    end.map(&:value)

    created = results - [:duplicate]
    assert_equal 1, created.length, "Expected one passenger, got #{created.length}"
    row = CassandraClient.session.execute(
      'SELECT id FROM passengers_by_document WHERE document_type = ? AND document_number = ?',
      arguments: ['CC', document]).first
    assert_equal created.first, row['id'].to_s
    puts "PASS registro concurrente: 5 intentos => 1 pasajero"
  end
end
