# SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
# SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
# SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
# SPDX-License-Identifier: Apache-2.0

# eBank Dockerfile — Flutter web build
FROM ghcr.io/cirruslabs/flutter:3.22.0 AS build

WORKDIR /app
COPY pubspec.yaml /app/
RUN flutter pub get
COPY . /app/
RUN flutter build web --release

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 3005
CMD ["nginx", "-g", "daemon off;"]