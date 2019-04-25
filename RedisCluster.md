# 部署Redis集群

参考资料  
[Redis cluster tutorial](https://redis.io/topics/cluster-tutorial)  
[Redis集群教程](http://www.redis.cn/topics/cluster-tutorial.html)（中文翻译已过时）  
[Redis 的 Sentinel 文档](http://www.redis.cn/topics/sentinel.html)

## 目标

构建数据分片的高可用Redis集群，预期做3个Master3个Slave，一个Master对应一个Slave。
Master之间通过哈希槽做数据分片，Slave之间通过主从复制和Redis哨兵实现系统高可用性。

注意：企业应用系统Redis集群节点应该是位于不同的机器上面的。

关于哈希槽算法的原理及对比一致性哈希算法的说明  
[进阶的Redis之哈希分片原理与集群实战](https://www.jianshu.com/p/b54267d24253)

## Redis集群部署实操

### 使用Redis Docker镜像部署

1. 直接使用官方的Redis镜像

    [Docker Hub上的官方镜像](https://hub.docker.com/_/redis)

    ```ignore
    redis               5.0.1-alpine         28d359e5d4bb        5 months ago        40.9MB
    ```

2. 创建6个节点的redis.conf文件

    假设六个节点的名称分别为 redis_01m redis_02m redis_03m redis_01s redis_02s redis_03s。
    修改下面配置项。

    ```conf
    # daemonize no
    # port 6379
    # logfile "/home/lee/deploy/redis_cluster/log/redis_01m.log"
    appendonly yes
    cluster-enabled yes
    cluster-config-file nodes.conf
    cluster-node-timeout 5000
    ```

3. 使用docker-compose启动这6个节点

    启动之后默认全部为Master。

    设置主从，可以进入redis_01s、redis_02s、redis_03s，执行下面命令设置主从，然后通过设置哨兵模式实现主机异常时主从切换，如果使用redis-trib脚本创建集群则无需执行这步。

    ```sh
    SLAVEOF 172.17.0.3 [容器外部port]
    ```

4. 使用 redis-trib 创建集群

    官方提供了redis-trib脚本用于快捷创建redis集群，实现了自动进行主从与切换，数据分片
    及重新分片等设置。

    首先需要安装Ruby运行环境

    ```sh
    yum install ruby
    # 需要安装ruby的redis客户端
    gem install redis --version 3.0.7
    ```

    构建redis集群

    ```sh
    # "IPAddress": "172.20.0.3", redis_01m
    # "IPAddress": "172.20.0.7", redis_01s
    # "IPAddress": "172.20.0.2", redis_02m
    # "IPAddress": "172.20.0.4", redis_02s
    # "IPAddress": "172.20.0.5", redis_03m
    # "IPAddress": "172.20.0.6", redis_03s
    # 创建redis集群
    # 如果不是用docker
    #./redis-trib.rb create --replicas 1 127.0.0.1:6380 127.0.0.1:6381 \
    #127.0.0.1:6382 127.0.0.1:6383 127.0.0.1:6384 127.0.0.1:6385
    # 使用docker创建集群，要使用docker的内网
    ./redis-trib.rb create --replicas 1 172.20.0.3:6379 172.20.0.7:6379 \
    172.20.0.2:6379 172.20.0.4:6379 172.20.0.5:6379 172.20.0.6:6379
    # redis集群重新分片
    ./redis-trib.rb reshard 127.0.0.1:7000
    # 添加新的节点，第一个参数是新节点的地址，第二个参数是任意一个已经存在的节点的IP和端口
    ./redis-trib.rb add-node 127.0.0.1:7006 127.0.0.1:7000
    ./redis-trib.rb add-node --slave 127.0.0.1:7006 127.0.0.1:7000
    # 移除一个节点，第一个参数是任意一个节点的地址,第二个节点是你想要移除的节点地址。使用同样的方法移除主节点,不过在移除主节点前，需要确保这个主节点是空的。
    ./redis-trib del-node 127.0.0.1:7000 127.0.0.1:7006
    ```

    选项–replicas 1 表示我们希望为集群中的每个主节点创建一个从节点。
    注意: 如果你是使用脚本创建的集群节点，那么默认端口可能是从30001开始。

    实验发现redis-trib.rb已经不再使用，下面是推荐的做法。

    ```sh
    redis-cli --cluster create 172.20.0.3:6379 172.20.0.2:6379 172.20.0.5:6379 172.20.0.7:6379 172.20.0.4:6379 172.20.0.6:6379 --cluster-replicas 1 -a password
    ```

    如果想要手动创建redis集群可以参考 [docker 实现redis集群搭建](https://www.cnblogs.com/cxbhakim/p/9151720.html)

5. 集群测试

    redis-cli 程序实现了非常基本的集群支持， 可以使用命令 redis-cli -c 来启动。

    ```sh
    redis-cli -c -p 6380    # -c 必需是第一个参数
    ```

    可以参考这个拓展的脚本  
    Ruby版：[redis-rb-cluster](https://github.com/antirez/redis-rb-cluster)  
    Python版：[redis-py-cluster](https://github.com/Grokzen/redis-py-cluster)  
