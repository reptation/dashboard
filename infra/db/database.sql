
CREATE DATABASE dashboard;
\c dashboard;

CREATE TABLE hardware (
  id integer primary key,
  provider text not null,
  name text not null);

INSERT INTO hardware(provider, name) VALUES ('Amazon', 'c5');
INSERT INTO hardware(provider, name) VALUES ('Azure', 'H16mr');
