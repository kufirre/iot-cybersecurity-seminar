![WE Logo](resources/WE_Logo_small_t.png)
# **IoT cybersecurity workshop**
This guide will take you through the practical exercises of the IoT cybersecurity workshop. 

## **Prerequisites**
In order to go through this workshop you will need the following.

### **Hardware**
1. The [**Cordelia-I EV-Kit**](https://www.we-online.com/en/components/products/CORDELIA-I#/articles/SIZE_CORDELIA-I_KIT). This will be made available if you are attending a seminar. Contact [**wcs@we-online.com**](mailto:wcs@we-online.com) or your local sales contact to get your kit.

2. A windows computer with internet access.

3. A WiFI access point (IEEE 802.11 b/g/n compatible) with internet access and with WPA2 personal or WPA3 personal mode.

### **Software**
1. A **chromium** based browser. It is recommended to use Edge or Chrome browser.

2. Install [**drivers**](https://ftdichip.com/drivers/vcp-drivers/) for the UART-to-USB chip on the Cordelia-I EV-board.

3. The [**WE UART terminal**](https://www.we-online.com/components/products/media/674801).

:warning: This tool works only on Windows platform. This tool may require installation of dotnet runtime. If this is not already installed, please [download](https://dotnet.microsoft.com/en-us/download/dotnet/thank-you/runtime-6.0.36-windows-x64-installer) and install this package.

:warning: If you are using any other platform, please use any serial terminal of choice or the built-in serial terminal from QuarkLink™.

4. An e-mail address to create a [QuarkLink™](https://www.cryptoquantique.com/products/quarklink/) account. Make sure that you have access to this account during the registration process.

5. (Optional) AWS and/or Azure accounts.

6. MQTT explorer, a MQTT client available on multiple platform. [Download](https://mqtt-explorer.com/) and install the same.

### **Know-how**
It is nice to have a basic understanding of the following topics. However, you can go through this workshop and get to know the required concepts on the way.

1. Basics of  [**WiFi** technology](https://en.wikipedia.org/wiki/WiFI).

2. [**TCP/IP** networking](https://en.wikipedia.org/wiki/Internet_protocol_suite).

3. [**MQTT** protocol](https://mqtt.org/getting-started/).

4. [**TLS** protocol](https://en.wikipedia.org/wiki/Transport_Layer_Security).

5. [**Digital certificates**](https://en.wikipedia.org/wiki/Public_key_certificate) and their use in [**TLS**](https://aws.amazon.com/what-is/ssl-certificate/?nc1=h_ls).



## Practical exercises

[**Exercise 1**: Connect Cordelia-I EV board to the internet](exercise1.md)

[**Exercise 2**: Hands-on with MQTT protocol (without security)](exercise2.md)

[**Exercise 3**: MQTT over TLS](exercise3.md)

[**Exercise 4**: (Optional) MQTT over mTLS using Cordelia-I and AWS](exercise4.md)

[**Exercise 5**: Secure cloud connectivity using Cordelia-I and QuarkLink™](exercise5.md)
