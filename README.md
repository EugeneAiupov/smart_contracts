# BlockchainVPN Smart-Contract

[English](#english) | [Russian](#russian)

## English

## Overview

BlockchainVPN is a smart contract designed for managing a decentralized VPN service on the Ethereum blockchain.

## Contract Structure

### State Variables

- User: A structure that holds user's balance and activity status.
- users: A public mapping that stores User structures indexed by user addresses.
- owner: A public address of the contract owner.
- stopped: A private boolean flag used to control the emergency stop feature.

### Events

- UserRegistered, DepositMade, ServiceUsed, WithdrawalMade, EmergencyStopped, EmergencyStarted

### Functions / Функции

#### constructor(), register(), deposit(), useService(uint256 amount), withdraw(uint256 amount), emergencyStop(), resumeService()

## Russian

## Обзор

BlockchainVPN — это смарт-контракт, предназначенный для управления децентрализованным VPN-сервисом на блокчейне Ethereum.

## Структура Контракта

### Состояние Переменных

- User: Структура, которая содержит баланс пользователя и статус активности.
- users: Публичное отображение, которое хранит структуры User, индексированные по адресам пользователей.
- owner: Публичный адрес владельца контракта.
- stopped: Приватный булевый флаг, используемый для контроля функции аварийной остановки.
