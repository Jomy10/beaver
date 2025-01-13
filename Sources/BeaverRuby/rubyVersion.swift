import RubyGateway
import Beaver

public func rubyVersionDescription() -> String {
  Ruby.versionDescription
}

public func rubyApiVersion() -> Version {
  Version(Ruby.apiVersion)
}
