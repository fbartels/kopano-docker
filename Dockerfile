FROM alpine
RUN --mount=type=secret,id=apt_auth,dst=/etc/apt/auth.conf cat /etc/apt/auth.conf # shows secret from custom secret location
