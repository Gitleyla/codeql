/**
 * @name Certificate not checked
 * @description Always check the result of certificate verification after fetching an SSL certificate.
 * @kind problem
 * @problem.severity error
 * @security-severity TODO
 * @precision TODO
 * @id cpp/certificate-not-checked
 * @tags security
 *       external/cwe/cwe-295
 */

import cpp
import semmle.code.cpp.valuenumbering.GlobalValueNumbering
import semmle.code.cpp.controlflow.IRGuards

/**
 * A call to `SSL_get_peer_certificate`.
 */
class SSLGetPeerCertificateCall extends FunctionCall {
  SSLGetPeerCertificateCall() {
    getTarget().getName() = "SSL_get_peer_certificate" // SSL_get_peer_certificate(ssl)
  }

  Expr getSSLArgument() { result = getArgument(0) }
}

/**
 * A call to `SSL_get_verify_result`.
 */
class SSLGetVerifyResultCall extends FunctionCall {
  SSLGetVerifyResultCall() {
    getTarget().getName() = "SSL_get_verify_result" // SSL_get_peer_certificate(ssl)
  }

  Expr getSSLArgument() { result = getArgument(0) }
}

/**
 * Holds if the SSL object passed into `SSL_get_peer_certificate` is checked with
 * `SSL_get_verify_result` entering `node`.
 */
predicate resultIsChecked(SSLGetPeerCertificateCall getCertCall, ControlFlowNode node) {
  exists(Expr ssl, SSLGetVerifyResultCall check |
    ssl = globalValueNumber(getCertCall.getSSLArgument()).getAnExpr() and
    ssl = check.getSSLArgument() and
    node = check
  )
}

/**
 * Holds if the certificate returned by `SSL_get_peer_certificate` is found to be
 * `0` on the edge `node1` to `node2`.
 */
predicate certIsZero(
  SSLGetPeerCertificateCall getCertCall, ControlFlowNode node1, ControlFlowNode node2
) {
  exists(GuardCondition guard, Expr cert |
    cert = globalValueNumber(getCertCall).getAnExpr() and
    (
      exists(Expr zero |
        zero.getValue().toInt() = 0 and
        node1 = guard and
        (
          // if (cert == zero) {
          guard.comparesEq(cert, zero, 0, true, true) and
          node2 = guard.getATrueSuccessor()
          or
          // if (cert != zero) { }
          guard.comparesEq(cert, zero, 0, false, true) and
          node2 = guard.getAFalseSuccessor()
        )
      )
      or
      // if (cert) { }
      guard = cert and
      node1 = guard and
      node2 = guard.getAFalseSuccessor()
      or
      // if (!cert) {
      node1 = guard.getParent() and
      node2 = guard.getParent().(NotExpr).getATrueSuccessor()
    )
  )
}

/**
 * Holds if the SSL object passed into `SSL_get_peer_certificate` has not been checked with
 * `SSL_get_verify_result` at `node`. Note that this is only computed at the call to
 * `SSL_get_peer_certificate` and at the start and end of `BasicBlock`s.
 */
predicate certNotChecked(SSLGetPeerCertificateCall getCertCall, ControlFlowNode node) {
  // cert is not checked at the call to `SSL_get_peer_certificate`
  node = getCertCall
  or
  exists(BasicBlock bb, int pos |
    // flow to end of a `BasicBlock`
    certNotChecked(getCertCall, bb.getNode(pos)) and
    node = bb.getEnd() and
    // check for barrier node
    not exists(int pos2 |
      pos2 > pos and
      resultIsChecked(getCertCall, bb.getNode(pos2))
    )
  )
  or
  exists(BasicBlock pred, BasicBlock bb |
    // flow from the end of one `BasicBlock` to the beginning of a successor
    certNotChecked(getCertCall, pred.getEnd()) and
    bb = pred.getASuccessor() and
    node = bb.getStart() and
    // check for barrier bb
    not certIsZero(getCertCall, pred.getEnd(), bb.getStart())
  )
}

from SSLGetPeerCertificateCall getCertCall, ControlFlowNode node
where
  certNotChecked(getCertCall, node) and
  node instanceof Function // (function exit)
select getCertCall,
  "This " + getCertCall.toString() + " is not followed by a call to SSL_get_verify_result."
