-- Seed data for departments
INSERT INTO departments (name, code, campus, contact_email, contact_phone, head_name) VALUES
('College of Arts and Sciences', 'CAS', 'Main Campus', 'cas@psu.edu', '+63 9XX XXX XXXX', 'Dr. Maria Santos'),
('College of Engineering', 'COE', 'Main Campus', 'coe@psu.edu', '+63 9XX XXX XXXX', 'Engr. Juan Dela Cruz'),
('College of Business', 'COB', 'Main Campus', 'cob@psu.edu', '+63 9XX XXX XXXX', 'Dr. Antonio Reyes'),
('College of Education', 'COED', 'Main Campus', 'coed@psu.edu', '+63 9XX XXX XXXX', 'Dr. Patricia Lopez'),
('College of Information Technology', 'CIT', 'Main Campus', 'cit@psu.edu', '+63 9XX XXX XXXX', 'Engr. Carlos Rodriguez');

-- Seed data for buildings
INSERT INTO buildings (name, code, campus, address, floors, building_manager) VALUES
('Main Academic Building', 'MAB', 'Main Campus', 'Downtown Area', 4, 'Mr. Jose Garcia'),
('Engineering Building A', 'EBA', 'Main Campus', 'North Campus', 5, 'Mr. Robert Martinez'),
('Engineering Building B', 'EBB', 'Main Campus', 'North Campus', 4, 'Ms. Diana Flores'),
('Science Complex', 'SC', 'Main Campus', 'South Campus', 6, 'Dr. Francisco Gonzales'),
('Administration Building', 'AB', 'Main Campus', 'Central Area', 3, 'Mr. Miguel Torres');

-- Seed data for request types
INSERT INTO request_types (name, code, description) VALUES
('Ocular Inspection', 'OI', 'Visual inspection and assessment'),
('Installation', 'INST', 'Equipment or system installation'),
('Repair', 'REP', 'Equipment or system repair'),
('Replacement', 'REPL', 'Equipment or system replacement'),
('Router Inspection', 'RI', 'Network router inspection and maintenance'),
('Remediation', 'REM', 'Remediation work for safety or compliance'),
('Preventive Maintenance', 'PM', 'Regular preventive maintenance'),
('Emergency Repair', 'ER', 'Urgent emergency repairs');
