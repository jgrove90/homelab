# Use an official Python runtime as a base image
FROM python:3.12

# Set working directory
WORKDIR /app

# Copy your Python script
COPY dynamic_ip_updater.py .
COPY requirements.txt .

# Copy the cron job
COPY cronjob /etc/cron.d/cronjob

# Install Python dependencies
# Create and activate a virtual environment, then install requirements
RUN python3 -m venv .venv && \
    . .venv/bin/activate && \
    pip3 install -r requirements.txt


# Install cron
RUN apt-get update && \
    apt-get install -y cron


# Add cron job to the cron table
RUN chmod 0644 /etc/cron.d/cronjob && \
    chmod +x /app/dynamic_ip_updater.py && \
    crontab /etc/cron.d/cronjob

# Run cron in the foreground
CMD ["cron", "-f"]
