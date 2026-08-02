FROM rust:1.95-trixie AS builder

WORKDIR /app
COPY apps/ml-service/Cargo.toml apps/ml-service/Cargo.lock ./
COPY apps/ml-service/src ./src
RUN cargo build --locked --release

FROM archlinux:latest AS runner

WORKDIR /app
ENV MODEL_PATH=/app/model/model.onnx
ENV MODEL_INPUT_SIZE=224
ENV ML_SERVICE_HOST=0.0.0.0
ENV ML_SERVICE_PORT=4012
ENV RUST_LOG=info

RUN pacman -Syu --noconfirm ca-certificates 2>/dev/null

COPY --from=builder /app/target/release/zeavis-ml-service /usr/local/bin/zeavis-ml-service
COPY Machine_Learning/model/model.onnx /app/model/model.onnx

EXPOSE 4012
CMD ["zeavis-ml-service"]
