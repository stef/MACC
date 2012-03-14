Simple Multi-agent encryption

Dependencies
apt-get install seccure apg ksh

RUNNING THE PoC```

 # Running the "broadcast channel" simulator :)
 cd server
 sh ./multiplexer.sh

 # Running agents - as many as you want

 # open a new shell,
 # create a pristine directory for an agent
 mkdir -p agent1
 cd agent1/
 macc.sh <path to server> # run an agent```

On 1st run this automatically generates a private/public keypair. Exchange the public part with your peers and add to a file called peers prefixed with some nickname for the user agent1/peers should look like this```

 agent2 <long random string>
 agent3 <other long random string>
 ...```

macc.sh now runs in the foreground and waits for keyboard input to be broadcast to all participants in the chat.

let's create 2 more agents```
 # open a new terminal
 mkdir -p agent2
 cd agent2/
 macc.sh <path to server>

 # open a new terminal
 mkdir -p agent3
 cd agent3/
 macc.sh <path to server>```

and let's create the agents peer files:```
 for i in $(seq 1 3); do (echo -n "agent$i"; cat agent$i/pub) >>agent1/peers; done cp agent1/peers agent2/peers; cp agent1/peers agent3/peers```

Now restart all macc instances, and send message from one to the other. You can see what happens in the socket files and in the server/out file.

Protocol

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

