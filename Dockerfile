FROM centos:centos7
ENV NODE_ENV prod
RUN yum install -y epel-release
RUN yum install -y nodejs npm
RUN npm install coffee-script
# RUN useradd -ms /bin/bash william
# WORKDIR /home/william
WORKDIR vair_seven_reconciliation
COPY . .
# RUN chown -R william:william /home/william
# USER william
# VOLUME ["/home/william/vair_seven_reconciliation/log"]
VOLUME ["/vair_seven_reconciliation/log"]
# WORKDIR vair_seven_reconciliation
CMD npm start