# 云服务器部署

## 部署简介

**1. 只有一台阿里云的服务器，初期设想，分为以下几个模块**：

  + 个人网站
  + 个人博客
  + 开源项目

  里面的模块都通过docker搭建，每个部分实现一个脚本实现自动化启动关闭（因为多个模块同时开始内存可能会紧张）

  结构上定为下面所示：
  + **Nginx**(docker)
    - **个人网站**
    
    - **个人博客**
    
    - **开源项目**  
      为模拟企业环境，采用集群部署，希望能像这样一步步演进
https://www.cnblogs.com/winner-0715/p/5058972.html
        * **Tomcat应用服务器**（多台）   
        * **Redis服务器**（一致性Hash算法部署的多台服务器）  
        * **主从复制MySQL服务器**（多台）  
        * **FTP文件服务器（一台）**  
        ![项目结构](http://www.hollischuang.com/wp-content/uploads/2015/12/5.png)  
        ![最终希望达到的结构](http://www.hollischuang.com/wp-content/uploads/2015/12/10.png)

    - **FTP文件服务器**  
    
**2. 服务器部署规范**  

  为了后面部署项目不显杂乱，提前做些规定和端口号分配。

  端口号分配：   
  22：    系统占用  
  3380：  系统占用  
  80：    HTTP默认端口  
  8081/8082：web应用  
  9000: FTP服务器  

## Nginx服务器搭建和配置

Nginx服务器也通过Docker部署, 具体参考《Complete NGINX Cookbook》 Chapter 24. Deploying on Docker。

这里暂时只用到反向代理和负载均衡的配置，还有一些安全性、高可用性配置后面会继续添加。后面会配置好完整的配置然后创建一个新的镜像，并上传到 DaoCloud 镜像仓库。

快速启动： https://dashboard.daocloud.io/packages/2b7310fb-1a50-48f2-9586-44622a2d1771

使用的 Nginx Docker 镜像
```
# docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
nginx               1.13.11-alpine      2dea9e73d89e        5 months ago        18MB
# docker container ls -a
CONTAINER ID        IMAGE                  COMMAND                  CREATED             STATUS                      PORTS               NAMES
512feb4ccb0c        nginx:1.13.11-alpine   "nginx -g 'daemon of…"   5 months ago        Exited (0) 33 minutes ago                       httpd_alpine
```

Nginx容器创建配置与启动
```
# Nginx 服务器配置 /etc/nginx/conf.d/kwseeker.top.conf
# 添加 博客、电子商城、文件服务

# kwseeker.top servers configuration
#================== web applications server ====================#
# blog server
server {
    listen 80;
    server_name blog.kwseeker.top;
    location / {
        proxy_pass http://localhost:8081;
    }
}

server {
    listen 8081;
    server_name localhost;

    location / {
        root    /usr/share/nginx/html;
        index   blog.html;
    }
}

# emall server
server {
    listen 80;
    server_name emall.kwseeker.top;
    location / {
        proxy_pass http://localhost:8082;
    }
}


server {
    listen 8082;
    server_name localhost;

    location / {
        root    /usr/share/nginx/html;
        index   emall.html;
    }
}

#========================= file server =========================#
server {
    listen 80;
    default_type 'text/html';
    charset utf-8;

    # list add directories
    autoindex on;
    autoindex_exact_size off;
    autoindex_localtime on;

    server_name docs.kwseeker.top;

    #access_log /usr/local/nginx/logs/access.log combined;
    index index.html index.htm index.jsp index.php;

    #error_page 404 /404.html;
    if ( $query_string ~* ".*[\;'\<\>].*" ){
        return 404;
    }

    location ~ /(mmall_fe|mmall_admin_fe)/dist/view/* {
        deny all;
    }

    location / {
        root /root/deploy/fauria/docs/;
        add_header Access-Control-Allow-Origin *;
    }
}

server {
    listen 80;
    charset utf-8;

    # list add directories
    autoindex on;
    autoindex_exact_size off;
    autoindex_localtime on;

    server_name images.kwseeker.top;

    #access_log /usr/local/nginx/logs/access.log combined;
    index index.html index.htm index.jsp index.php;

    #error_page 404 /404.html;
    if ( $query_string ~* ".*[\;'\<\>].*" ){
        return 404;
    }

    location ~ /(mmall_fe|mmall_admin_fe)/dist/view/* {
        deny all;
    }

    location / {
        root /root/deploy/fauria/images/;
        add_header Access-Control-Allow-Origin *;
    }

}

# docker run 创建并启动容器
docker run \
  --name nginx_proxy \
  -p 80:80 \
  -p 443:443 \
  -v /root/deploy/nginx/conf/conf.d:/etc/nginx/conf.d \
  -v /root/deploy/nginx/conf/nginx.conf:/etc/nginx/nginx.conf \
  -v /root/deploy/nginx/html:/usr/share/nginx/html \
  -v /root/deploy/nginx/log:/var/log/nginx \
  -v /root/deploy/fauria/images:/root/deploy/fauria/images \
  -v /root/deploy/fauria/docs:/root/deploy/fauria/docs \
  -d nginx:1.13.11-alpine

docker inspect ${ContainerId} # 查看容器配置详情及路径映射(Mounts字段)

# docker start 启动容器
docker start 
```

注意：  
1) 要使用二级域名（如：docs.kwseeker.top），首先需要手动将其添加到DNS解析列表里面，不然浏览器访问会报“Unknown Host”/“无法访问此网站”错误。
2) docker -v 读写有两种模式'rw', 'ro'， 默认为'rw'。  
'rw' 挂载目录，则可以双向读写同步； 挂载文件则docker的写可以同步到宿主机，反之不行。  
'ro' 挂载目录和文件，任何一端都不能向另一端读写同步，相当于在创建容器时从宿主机拷贝了一份不可改变的文件到Docker虚拟机。

## FTP服务器搭建
https://dashboard.daocloud.io/packages/150167f9-7b9e-4246-b67b-5f003def9077

```
docker pull fauria/vsftpd

# 测试运行
docker run --rm fauria/vsftpd

# 注意PASV_ADDRESS是容器在物理主机上的地址
docker run \
  --name fauria_vsftpd \
  -v /root/deploy/fauria:/home/vsftpd \
  -p 20:20 -p 21:21 -p 21100-21110:21100-21110 \
  -e FTP_USER=ftpuser -e FTP_PASS=112358 \
  -e PASV_ADDRESS=172.17.0.1 \
  -e PASV_MIN_PORT=21100 -e PASV_MAX_PORT=21110 \
  -d fauria/vsftpd


docker logs fauria_vsftpd

#手动添加新用户
docker exec -i -t fauria_vsftpd bash
mkdir /home/vsftpd/myuser
echo -e "myuser\nmypass" >> /etc/vsftpd/virtual_users.txt
/usr/bin/db_load -T -t hash -f /etc/vsftpd/virtual_users.txt /etc/vsftpd/virtual_users.db
exit
docker restart vsftpd

# 搭建测试
lftp ftpuser@127.17.0.1
lftp ftpuser@localhost      # 首先确认下 localhost 是 127.0.0.1 的别名

# 阿里云外网访问
添加安全组配置（控制端口和浮动端口）
ftp://xxx.xxx.xxx.xxx   #服务器公网IP
```

## Tomcat集群Docker实现
由于只有一台云服务器，就是用Docker模拟每个单独的web服务器，通过端口定位连接到每个Web Docker容器（如果有多台实体服务器，通过IP定位）。

#### 拉取Tomcat Docker镜像与启动容器
```
# Tomcat镜像拉取
docker search tomcat
docker pull tomcat:8.5

docker run -it --rm tomcat:8.5
docker exec -it <containerName> bash    
# 进去查看配置文件和webapps都存在哪, 并拷贝一份配置文件到本地目录 
# 配置文件 /usr/local/tomcat/conf
# webapps /usr/local/tomcat/webapps
# 日志文件 /usr/local/tomcat/logs
docker cp <containerName>:/usr/local/tomcat/conf/server.xml /root/deploy/tomcat/conf/

# Tomcat容器启动
启动两个容器
docker run \
  --name tomcat_emall1 \
  -v /root/deploy/tomcat/conf/server.xml:/usr/local/tomcat/conf/server.xml:ro \
  -v /root/deploy/tomcat/webapps/emall1:/usr/local/tomcat/webapps \
  -v /root/deploy/tomcat/logs/emall1:/usr/local/tomcat/logs \
  -p 8091:8080 \
  -d tomcat:8.5

docker run \
  --name tomcat_emall2 \
  -v /root/deploy/tomcat/conf/server.xml:/usr/local/tomcat/conf/server.xml:ro \
  -v /root/deploy/tomcat/webapps/emall2:/usr/local/tomcat/webapps \
  -v /root/deploy/tomcat/logs/emall2:/usr/local/tomcat/logs \
  -p 8092:8080 \
  -d tomcat:8.5

# 测试
curl localhost:8091
curl localhost:8092
```

#### 添加Nginx反向代理与负载均衡配置
创建一个新的配置文件 emall.conf
```
upstream emall_server {
    ip_hash;
    # server localhost:8090 down;
    server localhost:8091 weight=10;
    server localhost:8092 weight=20;
    # server localhost:8093 backup;
}

server {
    listen 80;
    server_name emall.kwseeker.top;

    location / {
        proxy_pass http://emall_server;
    }
}
```
注释掉 kwseeker.top.conf 中 emall.kwseeker.top 相关的无用配置

修改 nginx "docker run" 命令，添加容器连接
```
docker run \
  --name nginx_proxy \
  -p 80:80 \
  -p 443:443 \
  -v /root/deploy/nginx/conf/conf.d:/etc/nginx/conf.d \
  -v /root/deploy/nginx/conf/nginx.conf:/etc/nginx/nginx.conf \
  -v /root/deploy/nginx/html:/usr/share/nginx/html \
  -v /root/deploy/nginx/log:/var/log/nginx \
  -v /root/deploy/fauria/images:/root/deploy/fauria/images \
  -v /root/deploy/fauria/docs:/root/deploy/fauria/docs \
  --link tomcat_emall1:tomcat_emall1 \
  --link tomcat_emall2:tomcat_emall2 \
  -d nginx:1.13.11-alpine
```

#### 通路测试
外网连接 http://emall.kwseeker.top , 如果正确显示Tomcat页面则成功。

#### 部署实际项目

#### 项目测试

## Redis集群Docker实现
Redis有两个任务：作为Session服务器，实现Session分离与单点登录；作为MySQL数据库的缓存。

基于Docker搭建Redis集群，参考《RedisCluster.md》

## MySQL服务器集群
主从复制架构。