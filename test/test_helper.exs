Mox.defmock(Boonorbust2.HTTPClientMock, for: Boonorbust2.HTTPClient)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Boonorbust2.Repo, :manual)
