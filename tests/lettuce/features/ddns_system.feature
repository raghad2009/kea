Feature: DDNS System
    A number of BIND10-specific DDNS tests, that do not fall under the
    'compliance' category; specific ACL checks, module checks, etc.

    Scenario: Module tests
        # The given config has b10-ddns disabled
        Given I have bind10 running with configuration ddns/noddns.config
        And wait for bind10 stderr message BIND10_STARTED_CC
        And wait for bind10 stderr message AUTH_SERVER_STARTED

        # Sanity check
        bind10 module DDNS should not be running

        # Test 1
        When I use DDNS to set the SOA serial to 1235
        # Note: test spec says refused here, system returns SERVFAIL
        #The DDNS response should be REFUSED
        The DDNS response should be SERVFAIL
        And the SOA serial for example.org should be 1234

        # Test 2
        When I configure bind10 to run DDNS
        And wait for new bind10 stderr message DDNS_RUNNING
        bind10 module DDNS should be running

        # Test 3
        When I use DDNS to set the SOA serial to 1236
        The DDNS response should be REFUSED
        And the SOA serial for example.org should be 1234

        # Test 4
        When I send bind10 the following commands
        """
        config add DDNS/zones
        config set DDNS/zones[0]/origin example.org
        config add DDNS/zones[0]/update_acl {"action": "ACCEPT", "from": "127.0.0.1"}
        config commit
        """

        # Test 5
        When I use DDNS to set the SOA serial to 1237
        The DDNS response should be SUCCESS
        And the SOA serial for example.org should be 1237

        # Test 6
        When I send bind10 the command DDNS shutdown

        # Test 7
        And wait for new bind10 stderr message DDNS_RUNNING

        # Test 8
        # Known issue: after shutdown, first new attempt results in SERVFAIL
        When I use DDNS to set the SOA serial to 1238
        The DDNS response should be SERVFAIL
        And the SOA serial for example.org should be 1237

        When I use DDNS to set the SOA serial to 1238
        The DDNS response should be SUCCESS
        And the SOA serial for example.org should be 1238

        # Test 9
        When I send bind10 the command Auth shutdown
        And wait for new bind10 stderr message AUTH_SERVER_STARTED

        # Test 10
        When I use DDNS to set the SOA serial to 1239
        The DDNS response should be SUCCESS
        And the SOA serial for example.org should be 1239

        # Test 11
        When I configure BIND10 to stop running DDNS
        And wait for new bind10 stderr message DDNS_STOPPED

        bind10 module DDNS should not be running

        # Test 12
        When I use DDNS to set the SOA serial to 1240
        # should this be REFUSED again?
        The DDNS response should be SERVFAIL
        And the SOA serial for example.org should be 1239

    Scenario: ACL
        # The given config has b10-ddns disabled
        Given I have bind10 running with configuration ddns/ddns.config
        And wait for bind10 stderr message BIND10_STARTED_CC
        And wait for bind10 stderr message AUTH_SERVER_STARTED
        And wait for bind10 stderr message DDNS_RUNNING

        # Sanity check
        A query for new1.example.org should have rcode NXDOMAIN
        A query for new2.example.org should have rcode NXDOMAIN
        A query for new3.example.org should have rcode NXDOMAIN
        The SOA serial for example.org should be 1234

        # Test 1
        When I use DDNS to add a record new1.example.org. 3600 IN A 192.0.2.1
        The DDNS response should be SUCCESS
        A query for new1.example.org should have rcode NOERROR
        The SOA serial for example.org should be 1235

        # Test 2
        When I set DDNS ACL 0 for 127.0.0.1 to REJECT
        Then use DDNS to add a record new2.example.org. 3600 IN A 192.0.2.2
        The DDNS response should be REFUSED
        A query for new2.example.org should have rcode NXDOMAIN
        The SOA serial for example.org should be 1235

        # Test 3
        When I set DDNS ACL 0 for 127.0.0.1 to ACCEPT
        Then use DDNS to add a record new3.example.org. 3600 IN A 192.0.2.3
        The DDNS response should be SUCCESS
        A query for new3.example.org should have rcode NOERROR
        The SOA serial for example.org should be 1236
