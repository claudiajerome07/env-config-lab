FROM node:18-alpine

WORKDIR /usr/src/app

COPY app/package*.json ./
RUN npm install

COPY app/ .

# Configuration is injected at runtime via environment variables
# Do NOT hardcode secrets or config into the image

CMD [ "npm", "start" ]
