Simple Multi-agent encryption

NOTICE: this is a proof-of-concept, it provide only local communication. This is an experimental tool. You could however easily hack this to make it work over irc, using ii and nc for example... ;)

Dependencies

    apt-get install seccure apg ksh

RUNNING THE PoC

    # Running the "broadcast channel" simulator :)
    cd server
    sh ./multiplexer.sh

    # Running agents - as many as you want

    # open a new shell,
    # create a pristine directory for an agent
    mkdir -p agent1
    cd agent1/
    macc.sh <path to server> # run an agent

On 1st run this automatically generates a private/public keypair. Exchange the public part with your peers and add to a file called peers prefixed with some nickname. For the user agent1/peers should look like this:

    agent2 <long random string, which is agent2 public key>
    agent3 <other long random string, which is agent3 public key>
    ...

macc.sh now runs in the foreground and waits for keyboard input to be broadcast to all participants in the chat.
let's create 2 more agents

    # open a new terminal
    mkdir -p agent2
    cd agent2/
    macc.sh <path to server>
    
    # open a new terminal
    mkdir -p agent3
    cd agent3/
    macc.sh <path to server>

and let's create the agents peer files:

    for i in $(seq 1 3); do (echo -n "agent$i"; cat agent$i/pub) >>agent1/peers; done cp agent1/peers agent2/peers; cp agent1/peers agent3/peers

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

Sample session with 3 participants

    # first agent has italian names for the peers
    ../macc.sh ../server/
    01:45 -!- /tmp/tmp.TiOrRUrTOv dh request
    01:45 -!- /tmp/tmp.WsSHipXKVZ dh request
    01:45 -!- due        joined
    01:45 -!- tres       joined
    ohai
    01:45 <due       > hello world!
    01:45 <tres      > yippie!
    01:45 -!- tres       left
    01:46 -!- due        left

    # second agent seems to be english speaking
    ../macc.sh ../server/
    01:45 -!- /tmp/tmp.WsSHipXKVZ dh request
    01:45 -!- three      joined
    01:45 -!- /tmp/tmp.AkBH3lNAmz found
    01:45 -!- one        joined
    01:45 <one       > ohai
    hello world!
    01:45 <three     > yippie!
    01:45 -!- three      left

    # 3rd agent seems german
    ../macc.sh ../server/
    01:45 -!- /tmp/tmp.TiOrRUrTOv found
    01:45 -!- zwei       joined
    01:45 -!- /tmp/tmp.AkBH3lNAmz found
    01:45 -!- eins       joined
    01:45 <eins      > ohai
    01:45 <zwei      > hello world!
    yippie!

The broadcast channel contains this data

    agent:/tmp/tmp.WsSHipXKVZ
    agent:/tmp/tmp.TiOrRUrTOv
    agent:/tmp/tmp.AkBH3lNAmz
    msg:U2FsdGVkX19D1zvDLLfsvt/TsMh8nWd+F2WleeaImH1FrUsTl8eo5mHC3FnS: U2FsdGVkX18qi4F6vvH7mvhxhFNVpvQULHA0FCcnCFKRy1WGzsCLthKqb5n6spc52HeMVU6MSm+Q+Pb+7nPZFBoUq43TCrMg4+pj/s+2bNNJtaPDMpfVywnoVUjPlvgAxB9Yfn4grwLLWrI= U2FsdGVkX18/sY/nk3Sj4lvg7Am1NPGkiWl5lLmKRL/PSI7pZISmykl69cNx6De0Qv1OZrwUnc8iuyJYyOaFybSyCghiUBKHYZuNdDTwbTPtxsvxJi1TKVbE0DiUyw1ftnoB5+qXXIlSTeE=
    msg:U2FsdGVkX18hzmQCTpp9Fzf1Kw4GCqjgqqfH6r6Eoo3mBR16NVCKNPkD2pcE2N1ZctTKb3k=: U2FsdGVkX18ZyY35AHhGQ/Zv5oasDkcKf1KgStpAxVeNGho2GMBwg/mE06B0BNVSuGH9YxFz2CIWuNPO/moFlhkjXz0KdZbWuC6RMpwtI9zXxWqeFpJHwY8tVjueqKCitjklC/0nfJeZXeQ= U2FsdGVkX1/KqjzUqH104aPUaTNPgrK+x9cvpaKCu0HfquoVD9JhdFILCBsVbW2h9SWbmQo8ZVgkYSxc3CzY5GVY9XVo9Xe6deTvjjIUQMH2fQxbbslZOEbZnjR0bMdYOkbsd0ArIIMWDeg=
    msg:U2FsdGVkX18VL3gHylijRwEiqKl7Nrnq8DduXYXx+RgEJovRVqH9QE4/4jMNLo5U: U2FsdGVkX19XxF+Xa5a53vq9C0JDyjGB8rBw/vsEk2BOF6k3Fn7AQmmWbKDU6kwQ39/S2cz/k0+/PO5/BhFLnPGh3A0iuGYareSRtic2AlpgqFKMs6yI+FcwLWApug6ChTtLlAxyxdr9KsE= U2FsdGVkX1/zygLSauW+O8AMMkE4riLT+6D1FV/aPax94IHg8Qjd/CgFyQBTvPxJd38T+Da7UBacwUtLBkY0zd7qrf4Vy8LUtBdkGPkhHkNprC5whKyX579uKHazfXMqnHnAoiUREL9jsoQ=
    leave:/tmp/tmp.WsSHipXKVZ
    leave:/tmp/tmp.TiOrRUrTOv
    leave:/tmp/tmp.AkBH3lNAmz

The Agents have this in their "sockets"

agent1

    dh2:/tmp/tmp.TiOrRUrTOv:&gTEf?IDbV7Asmez~3+-%Tk6_UxYXC/XST<+T<1p%@Wy.K?sK]%INRqt||ju#R(wqkdX;O9c@|]g7(PD!
    auth:/tmp/tmp.TiOrRUrTOv:U2FsdGVkX1/R6j64FqZbucHZ2xqH0CbvMVKfmpzrnMJG88nSwdprgbrm7Q5TyQtgfYW+ZgURNgHqOm0NvsCdaJPCHRYmIVqdpMLjnlprzfBpQRpkMK/KgKLRz7MaIu5m1Kx69TwikaXRYTYB512sJoVoNB5WZLLFDCPoO7yVMawljY9Bjb0ZDAEzTcAKbMLr5gdgoR/9E1lLg2YUR84MM0drO2PU/OzdkAVYP71S/l6Ei/KwOG8aIng1ZmVygCb8PNf5LcNpXxE8m0KFXS1CjLngGj/5VWXvJk6W
    dh2:/tmp/tmp.AkBH3lNAmz:%zczJU-o;$!RiA}EwWq_ZL4%^!^IA-5M.<M-^j3ewZ)WKy@)3}UAk[5v3g)R$66*XLH)wL,c}D.7?eVT=
    auth:/tmp/tmp.AkBH3lNAmz:U2FsdGVkX18jruuclmmVKVpcSkB8rxMhStWpAP3PCSsiCGfZMFdwBjnKPN91uVTDCDNaH0e9E/0l2DZT1MF/yOjcB6eglonjn7YFaCm0Rn6p9af6Jb/ZCz8hqADA4IPVjjLRo60pAuxeW/W60gcXl0oeizGcfe659KzUVbCpHxGvqpmJNdp2MOSLt6NNiGJOCKMG1d5hM9NAobnvcCWGii153IYE8chgF6OTgtGcC12s880mNPqiRPbzj6GmglYWZJjnUImN82toJrIYOySOQgUmjJQg9bNSBLmK

agent2

    dh:/tmp/tmp.WsSHipXKVZ:#*vW6]:tRnKA)lg*~T:Z!|?l/XMqvHY><5^EmLI<I<KeSk?u+dRc_HJR3s<y5N^j5KOZTO%xSQ@-?9@E6
    auth2:/tmp/tmp.WsSHipXKVZ:U2FsdGVkX1+nNEfIwkwEaebTLRoDPOWQmN9/CjzjrMRYhTIN3mRMMK56CUomg0FoCJiJahywvoSL5LfFOc3QGQHnT6vV7HWau9JT3TURfHQKh6nV6Bpw2MIcKCi/dqpphH+/A/CAYJ2bTRFN23brtqBfGqEtWjpQmj50q0TB3TRH6DswfxoqlzcFtyfMTXjdY1RjQwPOHaRvAfoHZsPJbNUyX0TdlmJGFT9uAOnOZ4J9y0TMNFaW1C3vNCcQQqxG4t80PR8PQGXET/B3i09GijCIc5kExJ4xUPoE
    dh2:/tmp/tmp.AkBH3lNAmz:%krrGWX>ee=iXQpjY/Ld6w@6,+Cx;g||_!<{c$7}4]Co;n_JcZ/qV05PtgE_Z&if+dGp>?,$Ux!?iSRNv
    auth:/tmp/tmp.AkBH3lNAmz:U2FsdGVkX1801LJLnW9ou0njeD458b/sG9tj14wUUmKp0JyXEZUmy5A+y9exsnbXEwkzEOrB5O7n1p3EbxTvUwtX/KBP7NyvfyxZY7T6ZB33TnltldD3095T9lIqCf3BilFuxUtQjJRIf6FBTfTZp/K/iJsW0HDJglQVkEnYizw2Gflz3w+xtuqIZVnDrcwJ9XtHben0B+SxlOoHYRWQnX9YzR76Iau1oMvUBGrxVPa1454Pcs1Py2R6QfEIDiMTxIDqkYSmOI2xEjrWv8XSEFfnu3b0ZChZ/E3M

agent3

    dh:/tmp/tmp.TiOrRUrTOv:(+{LN6qxJVy:.-/;;lW0PeD5@[Jc7nfRr^xzfOh8B15pX!9USu(wdb?U,JX>ivBx6Rv=+l6PR(yx)PUS/
    dh:/tmp/tmp.WsSHipXKVZ:&ZHSV^cr1oL!N&gK_lX|rP4x2<aN3YIiEP59%DX{l295;u0WErsnhOl,nDqneo[HsDs)ks2MzK-[t8n*M
    auth2:/tmp/tmp.TiOrRUrTOv:U2FsdGVkX19xBJf607P4dEJq62I66P5b4ZFdM1tmOrrBBRhk56JBY0O3PX17KBgV4oDznx+NMjLBTiKUtnNbRWnNjhhKEhp8TSNf7aShbhBgpvWdXiN4btLRJafUa0PjrKG3ltjIjY1JDonkxT0L7He7fwF3IadaTw+3yelbs/uAve7IRiL0Bhl1JRvpQbu3iGSWP+rlWUJuUwhU/koVTFxuK5e6BPRZBAfp9x/iyZTjRg0DbFFuvEE197HrpCQa0KxErur0mU9vVdQEsCCVvcHNuFMpLkRFlbH7
    auth2:/tmp/tmp.WsSHipXKVZ:U2FsdGVkX18vfb5axdjrLq8QCltsDW7BLdcpBBqBSZjTwmOIgkfv8X5scgrUz05qiRBy8gBGIP+qveLuDbc27k2NHckHxOJ/ciDk07zogzi2FeemGK/pmRmSCvvZOQGcu17XQBMf2Wr8N+3507scFRBMvg7GAXkM12E/hMrdoF8Wq2a0334kpNdT+EceBRkPXQYspbbLzl3FiSy+OTRzMCXU68GC2AapKuTsjo8RWTr9CaM+Ci5JgCvWTkBRWHw/1CYacJbc/e3m0WAw52Tnw28GPMoZQIyUuad+
