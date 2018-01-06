-- phpMyAdmin SQL Dump
-- version 4.6.6deb4
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Erstellungszeit: 27. Dez 2017 um 23:15
-- Server-Version: 10.1.26-MariaDB-0+deb9u1
-- PHP-Version: 7.0.19-1

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Datenbank: `dustcloud`
--

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `cmdqueue`
--

CREATE TABLE `cmdqueue` (
  `cmdid` int(11) NOT NULL,
  `did` int(11) NOT NULL,
  `method` varchar(100) NOT NULL,
  `params` varchar(512) NOT NULL,
  `expire` datetime NOT NULL,
  `processed` datetime NOT NULL,
  `confirmed` tinyint(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `devices`
--

CREATE TABLE `devices` (
  `id` int(11) NOT NULL,
  `did` int(11) DEFAULT NULL,
  `mac` varchar(17) DEFAULT NULL,
  `name` varchar(20) DEFAULT NULL,
  `enckey` varchar(16) DEFAULT NULL,
  `vinda` varchar(16) NOT NULL,
  `token` varchar(32) DEFAULT NULL,
  `fw` varchar(50) DEFAULT NULL,
  `model` varchar(50) DEFAULT NULL,
  `serialnumber` varchar(20) NOT NULL,
  `ssid` varchar(50) DEFAULT NULL,
  `netinfo` varchar(100) NOT NULL,
  `last_contact` timestamp NULL DEFAULT NULL,
  `last_contact_from` varchar(50) NOT NULL,
  `last_contact_via` varchar(20) NOT NULL,
  `PurchaseDate` varchar(20) NOT NULL,
  `ProductionDate` varchar(20) NOT NULL,
  `Date_vinda` varchar(20) NOT NULL,
  `recovery_fw_ver` varchar(75) NOT NULL,
  `MCU` varchar(50) NOT NULL,
  `forward_to_cloud` int(1) NOT NULL DEFAULT '0',
  `full_cloud_forward` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `ota`
--

CREATE TABLE `ota` (
  `id` int(11) NOT NULL,
  `model` varchar(40) NOT NULL,
  `version` varchar(20) NOT NULL,
  `filename` varchar(100) NOT NULL,
  `md5` varchar(32) NOT NULL,
  `type` varchar(30) NOT NULL,
  `url` varchar(150) NOT NULL,
  `Builddate` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `raw`
--

CREATE TABLE `raw` (
  `id` int(11) NOT NULL,
  `did` varchar(50) NOT NULL,
  `direction` varchar(20) NOT NULL,
  `raw` text NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `statuslog`
--

CREATE TABLE `statuslog` (
  `id` int(11) NOT NULL,
  `did` int(11) NOT NULL DEFAULT '0',
  `data` text,
  `direction` varchar(20) DEFAULT NULL,
  `timestamp` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Indizes der exportierten Tabellen
--

--
-- Indizes für die Tabelle `cmdqueue`
--
ALTER TABLE `cmdqueue`
  ADD PRIMARY KEY (`cmdid`);

--
-- Indizes für die Tabelle `devices`
--
ALTER TABLE `devices`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `did` (`did`);

--
-- Indizes für die Tabelle `ota`
--
ALTER TABLE `ota`
  ADD PRIMARY KEY (`id`);

--
-- Indizes für die Tabelle `raw`
--
ALTER TABLE `raw`
  ADD PRIMARY KEY (`id`);

--
-- Indizes für die Tabelle `statuslog`
--
ALTER TABLE `statuslog`
  ADD PRIMARY KEY (`id`);

--
-- AUTO_INCREMENT für exportierte Tabellen
--

--
-- AUTO_INCREMENT für Tabelle `cmdqueue`
--
ALTER TABLE `cmdqueue`
  MODIFY `cmdid` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;
--
-- AUTO_INCREMENT für Tabelle `devices`
--
ALTER TABLE `devices`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;
--
-- AUTO_INCREMENT für Tabelle `ota`
--
ALTER TABLE `ota`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;
--
-- AUTO_INCREMENT für Tabelle `raw`
--
ALTER TABLE `raw`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;
--
-- AUTO_INCREMENT für Tabelle `statuslog`
--
ALTER TABLE `statuslog`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
