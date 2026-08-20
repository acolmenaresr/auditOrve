require "test_helper"

class Notifications::AssignedAlertWebhookServiceTest < ActiveSupport::TestCase
  FakeUser = Struct.new(:usuario, :full_name, keyword_init: true)

  class FakeNotification
    def initialize(attrs)
      @attrs = attrs
    end

    def id
      @attrs["id"]
    end

    def [](key)
      @attrs[key]
    end

    def occurred_at
      @attrs["dateZ"]
    end
  end

  class FakeHTTP
    attr_accessor :use_ssl, :open_timeout, :read_timeout
    attr_reader :captured_request

    def request(http_request)
      @captured_request = http_request

      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.instance_variable_set(:@read, true)
      def response.body
        "{}"
      end
      response
    end
  end

  test "posts assigned alert data as JSON to the webhook" do
    notification = FakeNotification.new(
      "id" => 42,
      "clave" => "ALT-42",
      "tipoAlerta" => "descarga_masiva",
      "motivo" => "Descarga fuera de horario",
      "severidad" => "critica",
      "estado" => "en_revision",
      "categoriaAlerta" => "operacion",
      "usuario" => "user@orve.mx",
      "accion" => "FileDownloaded",
      "operacion365" => "FileDownloaded",
      "archivo" => "contrato.pdf",
      "ip" => "1.2.3.4",
      "dateZ" => Time.zone.parse("2026-08-20 15:00:00 UTC")
    )

    assignee = FakeUser.new(
      usuario: "auditor@orve.mx",
      full_name: "Ana Auditora"
    )

    actor = FakeUser.new(
      usuario: "jefe@orve.mx",
      full_name: "Juan Jefe"
    )

    fake_http = FakeHTTP.new
    service = Notifications::AssignedAlertWebhookService.new(
      notification: notification,
      assignee: assignee,
      actor: actor
    )

    service.define_singleton_method(:http_client) { fake_http }

    result = service.call
    payload = JSON.parse(fake_http.captured_request.body)

    assert result[:ok]
    assert_equal "application/json", fake_http.captured_request["Content-Type"]
    assert_equal 42, payload["id"]
    assert_equal "ALT-42", payload["clave"]
    assert_equal "critica", payload["severidad"]
    assert_equal "en_revision", payload["estado"]
    assert_equal "auditor@orve.mx", payload["asignadoA"]
    assert_equal "Ana Auditora", payload["asignadoANombre"]
    assert_equal "jefe@orve.mx", payload["asignadoPor"]
    assert_equal "/alertas/42", payload["rutaAlerta"]
    assert_equal "contrato.pdf", payload["archivo"]
  end
end
