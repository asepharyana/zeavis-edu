{
  description = "ZeaVis Edu — Bun API + Rust ML + Vite web (Nix build)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages = {
          # ── API: Bun + Elysia + Drizzle (workspace) ────────────────
          api = pkgs.stdenvNoCC.mkDerivation {
            pname = "zeavis-api";
            version = "0.1.0";
            src = ./.;
            nativeBuildInputs = [ pkgs.bun ];

            buildPhase = ''
              export HOME="$TMPDIR"
              bun install --frozen-lockfile
              bun run --cwd packages/shared build
            '';

            installPhase = ''
              mkdir -p $out/bin $out/lib/zeavis-api
              cp -r package.json bun.lock bunfig.toml tsconfig.base.json $out/lib/zeavis-api/
              cp -r node_modules $out/lib/zeavis-api/node_modules
              cp -r apps $out/lib/zeavis-api/apps
              cp -r packages $out/lib/zeavis-api/packages
              cat > $out/bin/zeavis-api << WRAPPER
#!${pkgs.runtimeShell}
cd $out/lib/zeavis-api
exec ${pkgs.bun}/bin/bun apps/api/src/index.ts
WRAPPER
              chmod +x $out/bin/zeavis-api
            '';
          };

          # ── ML Service: Rust (axum + ort/onnxruntime) ──────────────
          ml-service = pkgs.stdenv.mkDerivation {
            pname = "zeavis-ml-service";
            version = "0.1.0";
            src = ./.;
            nativeBuildInputs = [ pkgs.rustc pkgs.cargo pkgs.pkg-config pkgs.cacert ];
            buildInputs = [ pkgs.openssl ];

            buildPhase = ''
              export HOME="$TMPDIR" CARGO_HOME="$TMPDIR/.cargo"
              export SRC_ROOT="$PWD"
              cd apps/ml-service
              cargo build --locked --release
            '';

            installPhase = ''
              cd "$SRC_ROOT"
              mkdir -p $out/bin $out/share/zeavis-ml
              cp apps/ml-service/target/release/zeavis-ml-service $out/bin/.zeavis-ml-service
              cp Machine_Learning/model/model.onnx $out/share/zeavis-ml/model.onnx
              cat > $out/bin/zeavis-ml-service << WRAPPER
#!${pkgs.runtimeShell}
export MODEL_PATH="$out/share/zeavis-ml/model.onnx"
export MODEL_INPUT_SIZE="224"
export ML_SERVICE_HOST="0.0.0.0"
export ML_SERVICE_PORT="8200"
export RUST_LOG="info"
exec $out/bin/.zeavis-ml-service
WRAPPER
              chmod +x $out/bin/zeavis-ml-service
            '';
          };

          # ── Web: Vite static + nginx ───────────────────────────────
          web = pkgs.stdenvNoCC.mkDerivation {
            pname = "zeavis-web";
            version = "0.1.0";
            src = ./.;
            nativeBuildInputs = [ pkgs.bun ];

            buildPhase = ''
              export HOME="$TMPDIR"
              bun install --frozen-lockfile
              bun run --cwd packages/shared build
              bun run --cwd apps/web build
            '';

            installPhase = ''
              mkdir -p $out/bin $out/etc $out/share/zeavis-web/html
              cp -r apps/web/dist/* $out/share/zeavis-web/html/
              cat > $out/etc/nginx.conf << CONF
error_log /var/lib/zeavis-web/nginx-error.log;
pid /var/lib/zeavis-web/nginx.pid;
events {}
http {
  include ${pkgs.nginx}/conf/mime.types;
  access_log /var/lib/zeavis-web/nginx-access.log;
  server {
    listen 8088;
    server_name _;
    root $out/share/zeavis-web/html;
    index index.html;

    location /api/ {
      proxy_pass http://127.0.0.1:3200/api/;
      proxy_set_header Host \$host;
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /metrics {
      proxy_pass http://127.0.0.1:3200/metrics;
      proxy_set_header Host \$host;
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location / {
      try_files \$uri \$uri/ /index.html;
    }
  }
}
CONF
              cat > $out/bin/zeavis-web << WRAPPER
#!${pkgs.runtimeShell}
mkdir -p /var/lib/zeavis-web
exec ${pkgs.nginx}/bin/nginx -c $out/etc/nginx.conf -p /var/lib/zeavis-web -g "daemon off;"
WRAPPER
              chmod +x $out/bin/zeavis-web
            '';
          };

          default = self.packages.${system}.api;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [ pkgs.bun pkgs.nodejs_22 pkgs.rustc pkgs.cargo ];
        };
      });
}
