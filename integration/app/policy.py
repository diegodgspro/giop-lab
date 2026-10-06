CI_UID = 'urn:uuid:9e68f0af-8b55-4b0e-95e4-07dc02a7f6cb'
HOST = 'GUA-LAB-SRV-WEB-001'
TRIGGER = 'GIOP-LAB: controlled web workload TCP unavailable'


def eligible(event):
    return (event.host_id, event.trigger_id, event.host, event.trigger) == ('10683', '25228', HOST, TRIGGER)
