/**
 * Provides default sources, sinks and sanitizers for reasoning about
 * string based query injection vulnerabilities, as well as extension
 * points for adding your own.
 */

import javascript

module SqlInjection {
  /**
   * A data flow source for string based query injection vulnerabilities.
   */
  abstract class Source extends DataFlow::Node { }

  /**
   * A data flow sink for string based query injection vulnerabilities.
   */
  abstract class Sink extends DataFlow::Node { }

  /**
   * A sanitizer for string based query injection vulnerabilities.
   */
  abstract class Sanitizer extends DataFlow::Node { }

  /** A source of remote user input, considered as a flow source for string based query injection. */
  class RemoteFlowSourceAsSource extends Source {
    RemoteFlowSourceAsSource() { this instanceof RemoteFlowSource }
  }

  /** An SQL expression passed to an API call that executes SQL. */
  class SqlInjectionExprSink extends Sink, DataFlow::ValueNode {
    override SQL::SqlString astNode;
  }

  /** An expression that sanitizes a value for the purposes of string based query injection. */
  class SanitizerExpr extends Sanitizer, DataFlow::ValueNode {
    SanitizerExpr() { astNode = any(SQL::SqlSanitizer ss).getOutput() }
  }

  /** An GraphQL expression passed to an API call that executes GraphQL. */
  class GraphqlInjectionSink extends Sink {
    GraphqlInjectionSink() { this instanceof GraphQL::GraphQLString }
  }

  /**
   * An LDAPjs sink.
   */
  class LdapJSSink extends Sink {
    LdapJSSink() {
      // A distinguished name (DN) used in a call to the client API.
      this = any(LDAPjs::ClientCall call).getArgument(0)
      or
      // A search options object, which contains a filter and a baseDN.
      this = any(LDAPjs::SearchOptions opt).getARhs()
      or
      // A call to "parseDN", which parses a DN from a string.
      this = LDAPjs::ldapjs().getMember("parseDN").getACall().getArgument(0)
    }
  }

  /**
   * A call to a function whose name suggests that it escapes LDAP search query parameter.
   */
  class FilterOrDNSanitizationCall extends Sanitizer, DataFlow::CallNode {
    // TODO: remove, or use something else? (AdhocWhitelistSanitizer?)
    FilterOrDNSanitizationCall() {
      exists(string sanitize, string input |
        sanitize = "(?:escape|saniti[sz]e|validate|filter)" and
        input = "[Ii]nput?"
      |
        this.getCalleeName()
            .regexpMatch("(?i)(" + sanitize + input + ")" + "|(" + input + sanitize + ")")
      )
    }
  }
}
