Simple Multi-agent encryption

Setting up a new agent
1. Agent generates its own static key

New user joins group
1. New agent announces unencrypted broadcast to the group.
2. Group members start DH key exchange with new agent
3. the new agent signs his ephemeral key with his static key and sends this to all group members
4. Group members verify signature, if successful they respond with their verification key signed by their own static key

Agent send encrypted broadcast
1. agent encrypts his message for each user seperately
2. agent sends the n encrypted messages to the broadcast channel
