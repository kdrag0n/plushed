#!/usr/bin/env python3

import collections
import os
from pathlib import Path

import matplotlib.pyplot as plt
import tensorflow as tf

from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.layers import Dense, Conv2D, Flatten, Dropout, MaxPooling2D


# Settings
BATCH_SIZE = 5
EPOCHS = 18
IMG_DIMS = (224, 224)


CorpusCounts = collections.namedtuple("CorpusCounts", ["android", "other", "total"])
Corpus = collections.namedtuple("Corpus", ["train_dir", "val_dir", "train_counts", "val_counts"])


def get_corpus_info():
    # Directories
    corpus_dir = Path("images")
    train_dir = corpus_dir / "train"
    val_dir = corpus_dir / "validation"

    # Training dataset counts
    android_tr = len(list((train_dir / "android").glob("*.jpg")))
    other_tr = len(list((train_dir / "other").glob("*.jpg")))
    total_tr = android_tr + other_tr
    tr_counts = CorpusCounts(android_tr, other_tr, total_tr)

    # Validation dataset counts
    android_val = len(list((val_dir / "android").glob("*.jpg")))
    other_val = len(list((val_dir / "other").glob("*.jpg")))
    total_val = android_val + other_val
    val_counts = CorpusCounts(android_val, other_val, total_val)

    # Print counts
    print(f"Training: {android_tr} Android, {other_tr} other, {total_tr} total")
    print(f"Validation: {android_val} Android, {other_val} other, {total_val} total")

    return Corpus(train_dir, val_dir, tr_counts, val_counts)


def get_data_generators(corpus):
    # Image generators
    train_image_generator = ImageDataGenerator(
        rescale=1 / 255,
        # Augmentations (random variations to mitigate overfitting)
        horizontal_flip=True,
        rotation_range=45,
        zoom_range=0.5,
    )
    validation_image_generator = ImageDataGenerator(rescale=1 / 255)

    # Data loading generators
    train_data_gen = train_image_generator.flow_from_directory(
        batch_size=BATCH_SIZE, directory=corpus.train_dir, shuffle=True, target_size=IMG_DIMS, class_mode="categorical",
    )
    val_data_gen = validation_image_generator.flow_from_directory(
        batch_size=BATCH_SIZE, directory=corpus.val_dir, target_size=IMG_DIMS, class_mode="categorical"
    )

    return train_data_gen, val_data_gen


def construct_model():
    # Construct model
    model = tf.keras.Sequential(
        [
            Conv2D(16, 3, padding="same", activation="relu", input_shape=(*IMG_DIMS, 3)),
            MaxPooling2D(),
            Dropout(0.2),
            Conv2D(32, 3, padding="same", activation="relu"),
            MaxPooling2D(),
            Conv2D(64, 3, padding="same", activation="relu"),
            MaxPooling2D(),
            Dropout(0.2),
            Flatten(),
            Dense(512, activation="relu"),
            Dense(2, activation="sigmoid"),
        ]
    )

    # Compile model with metrics (for diagnosing)
    model.compile(optimizer="adam", loss="binary_crossentropy", metrics=["accuracy"])

    # Print model summary
    model.summary()

    return model


def train_model(model, corpus, train_data_gen, val_data_gen):
    # Train the model and validate it
    history = model.fit(
        train_data_gen,
        steps_per_epoch=corpus.train_counts.total // BATCH_SIZE,
        epochs=EPOCHS,
        validation_data=val_data_gen,
        validation_steps=corpus.val_counts.total // BATCH_SIZE,
    )

    return history


def plot_history(history):
    acc = history.history["accuracy"]
    val_acc = history.history["val_accuracy"]

    loss = history.history["loss"]
    val_loss = history.history["val_loss"]

    epochs_range = range(EPOCHS)

    plt.figure(figsize=(8, 8))
    plt.subplot(1, 2, 1)
    plt.plot(epochs_range, acc, label="Training Accuracy")
    plt.plot(epochs_range, val_acc, label="Validation Accuracy")
    plt.legend(loc="lower right")
    plt.title("Training and Validation Accuracy")

    plt.subplot(1, 2, 2)
    plt.plot(epochs_range, loss, label="Training Loss")
    plt.plot(epochs_range, val_loss, label="Validation Loss")
    plt.legend(loc="upper right")
    plt.title("Training and Validation Loss")
    plt.show()


def export_tflite(model, path):
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_model = converter.convert()
    with open(path, "wb+") as f:
        f.write(tflite_model)


def main():
    corpus = get_corpus_info()
    train_data_gen, val_data_gen = get_data_generators(corpus)
    model = construct_model()
    history = train_model(model, corpus, train_data_gen, val_data_gen)
    plot_history(history)
    export_tflite(model, "plushed_model.tflite")


if __name__ == "__main__":
    main()
