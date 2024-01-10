clear all;
tic;

Ann_File = zeros(10,10);
File_part = zeros(10,10);
counter_file =0;
AStress = zeros(600,3);
for file_number = 1:1:600

%     fprintf('file number = %d\n\n',file_number)
if file_number<10
    file_name = 'S0%dP.dat';
   else 
    file_name = 'S%dP.dat';
end

file_name_str = sprintf(file_name,file_number);
if exist(file_name_str, 'file') == 2
datatxt = dlmread(file_name_str,' ',[1 1 2 11]);

Straink = datatxt(1,3)*-1;
Stressk = sum(datatxt(1,6))/-1E6;

AStress(file_number,1:3) = [file_number,Stressk,Straink];
Stressko = Stressk ;
End = file_number;
end
end

AStress(AStress(:,1)==0,:) = [];

B = [];
for i=1:1:size(AStress,1)-1
B(i,1) = AStress(i+1,2)-AStress(i,2);
end

BB=[];
for i=1:1:size(B,1)-1
if (sign(B(i+1,1)) ~= sign(B(i,1)))
BB = [BB;i+1];
end
end

 Start = BB(end-1,1);
 Jump = 2;
 End = BB(end,1);
 %%
for file_number = Start:Jump:End
for requiredRk = [250E-6]
for Pressure = [1E5]
for Tc = 25:50:26

Tk = Tc+273.14;

       p1 =  -1.596e-09 ;
       p2 =   3.042e-06 ;
       p3 =   -0.001923  ;
       p4 =       2.591 ;
% 
% %Li4OSi4 
K_s = p4 + p3*Tc + p2*Tc^2 + p1*Tc^3;
mg = 119.85;

 
% % Li2TiO3
% 
% poro = 0.1;
% kbeta = 1.06-(2.88E-4)*Tk;
% K_s = ((1-poro)/(1+kbeta*poro))*(4.77 - (5.11E-3)*Tk + (3.12E-6)*Tk*Tk);
% mg=109.76;


%Helium
K_f0 = 3.366*(10^(-3))*(Tk.^(0.668));
mf=4;
dm = 2.15E-10;
visc = 1.865*(1e-5)*(Tk/273.16)^(0.7);


mr=mg/mf;
ac=2.4*(mr)/((1+mr)^2);
bsbeta=(19/12)*(2-ac)/ac;

kBo = 1.38E-23;

%%


Number_files = floor((End-Start)/Jump +1);

direction_cond = 3;

Bthres=100;
L_thres = 1;
Xi = 0.75;
cutoff_factor = 0.5;

 %Scaling effects

Top_temp = 10;
Bot_temp = 20;

D_Strain = 0.00015;


Delta_T = abs(Top_temp-Bot_temp);



    


    fprintf('file number = %d\n\n',file_number)
    


 %%
%Reading the file
   if file_number<10
    file_name = 'S0%dP.dat';
    else 
    file_name = 'S%dP.dat';
    end

file_name_str = sprintf(file_name,file_number);
N = dlmread(file_name_str,' ',2,0);
datatxt = dlmread(file_name_str,' ',[1 1 2 11]);
% fileID1 = fopen(file_name_str,'r');
% [datatxt,ScFCount] = fscanf(fileID1,'%s',50);
% fclose(fileID1);
Straink = datatxt(1,3)*-1;
Stressk = sum(datatxt(1,4:6))/(-3E6);
Stress123  = datatxt(1,4:6)/(-1E6);
Rmaxk = max(N(:,4));

Scfk = requiredRk/Rmaxk;
ScF = Scfk;

% ScF=0.016067;
% Scfk=ScF;
%Getting the scaling factor


%Adjusting with Scaling Factor
N(:,1:4) = Scfk*N(:,1:4);

%Sorting through the columns based on direction
N = sortrows(N,direction_cond);

N_particles = size(N,1);
mean_r  = mean(N(:,4));

N(:,8) = 1:1:N_particles;

% fprintf('Particle DATA is read\n');
%%
%Finding the periodic boundary particles

Other_dir = [1;2;3];
Other_dir(direction_cond) = [];

F1 = Other_dir(1);R1 = Other_dir(2);
ab=2.6;
PF = N(N(:,F1) < min(N(:,F1)) + ab*mean_r,:);
PB = N(N(:,F1) > max(N(:,F1)) - ab*mean_r,:);
PR = N(N(:,R1) < min(N(:,R1)) + ab*mean_r,:);
PL = N(N(:,R1) > max(N(:,R1)) - ab*mean_r,:);

PF_per = PF;
PB_per = PB;
PR_per = PR;
PL_per = PL;

PF_per(:,F1) = PF_per(:,F1) + ScF;
PB_per(:,F1) = PB_per(:,F1) - ScF;
PR_per(:,R1) = PR_per(:,R1) + ScF;
PL_per(:,R1) = PL_per(:,R1) - ScF;


%%
%Creating the contact list
M1 = contact_list(N,cutoff_factor,direction_cond);
M2 = contact_list_B(PF,PB_per,cutoff_factor);
M3 = contact_list_B(PR,PL_per,cutoff_factor);


C_List = [M1;M2;M3];
% C_List = M1;

N_contacts = size(C_List,1);

% fprintf('Contact list is made\n');

Cond = zeros(N_contacts,1);

N_overlap=0;
N_gap=0;
N_touch = 0;

%Conduction Matrix

for i=1:1:N_contacts
 
    P_1 = C_List(i,1); 
    P_2 = C_List(i,2);   
    d = C_List(i,3);
    
    r_1 = N(P_1,4);
    r_2 = N(P_2,4);
    r_eff = 2*r_1*r_2/(r_1+r_2);
    h12 = d-(r_1+r_2);
    rmin = min(r_1,r_2);
    rmax = min(r_1,r_2);
    
   if (Xi*r_eff < rmin)
    Gamma_1 = asind((Xi*r_eff)/r_1); 
    Gamma_2 = asind((Xi*r_eff)/r_2);
   else
       Gamma_1 = asind(rmin/r_1);
       Gamma_2 = asind(rmin/r_2);
   end
   
    if h12<0

        N_overlap = N_overlap+1;
        
        r_c = sqrt(abs(h12)*r_eff/2);
        
        theta1 = asind(r_c/r_1);
        theta2 = asind(r_c/r_2);
        C_List(i,5) = r_c;
                
         Lo1 = r_1*( 1- 0.5*( cos(theta1) + cos(Gamma_1) ) );
        Lo2 = r_2*( 1- 0.5*( cos(theta2) + cos(Gamma_2) ) );
%         Lo1 = r_1*(1- (4/3)*( ((cos(theta1))^3 - (cos(Gamma_1))^3)/(cos(2*theta1) - cos(2*Gamma_1)) ));
%         Lo2 = r_1*(1- (4/3)*( ((cos(theta2))^3 - (cos(Gamma_2))^3)/(cos(2*theta2) - cos(2*Gamma_2)) ));

        Lo=Lo1+Lo2 + h12;
        
        
        Hff = (visc/(Pressure*Lo))*sqrt(pi*8314*Tk/(2*mf));
        K_f = K_f0/(1+(2*bsbeta*Hff));
        C_List(i,12) = Lo;
        alpha = K_s/K_f;
        beta = alpha*r_c/r_eff;
        
        if beta < 1
          Kc = 0.22*(beta^2); DKg = -0.05*(beta^2);
        else if beta < Bthres
               Kc =  (beta-1)*(2*Bthres/pi-0.22)/(Bthres-1)+0.22 ;DKg =(beta-1)*(-2*log(Bthres)+0.05)/(Bthres-1)-0.05;
            else 
             Kc = 2*(beta)/pi; DKg = -2*log(beta);
            end
        end
        
        C_c = pi*K_f*r_eff*(Kc+DKg+log(alpha^2));
    else
                
        Lg1 = r_1*( 1- 0.5*( 1 + cos(Gamma_1) ) );
        Lg2 = r_2*( 1- 0.5*( 1 + cos(Gamma_2) ) );
%         Lg1 = r_1*(1 - (4/3)*(((1-(cos(Gamma_1))^3))/(1-cos(2*Gamma_1))));
%         Lg2 = r_2*(1 - (4/3)*(((1-(cos(Gamma_2))^3))/(1-cos(2*Gamma_2))));
        
        Lg = Lg1+Lg2+h12;
        C_List(i,13) = Lg;
        Hff = (visc/(Pressure*Lg))*sqrt(pi*8314*Tk/(2*mf));
        K_f = K_f0/(1+(2*bsbeta*Hff));
        alpha = K_s/K_f;
        lamda = (alpha^2)*h12/r_eff;
        
        if lamda < L_thres
            C_List(i,6) = h12;
            N_touch = N_touch+1;
%             C_c = pi*K_f*r_eff*log(alpha^2);
            C_c = pi*K_f*r_eff*(lamda*(log(1+Xi^2*alpha^2)-log(alpha^2)) + log(alpha^2));
        else
            N_gap = N_gap+1;
            C_List(i,7) = h12;
            C_List(i,8) = log(1 + (Xi^2)*r_eff/h12);
            C_c = pi*K_f*r_eff*log(1 + (Xi^2)*r_eff/h12);
        end
    end
    
    C_s1 = pi*K_s*(Xi*r_eff)^2/r_1;
    C_s2 = pi*K_s*(Xi*r_eff)^2/r_2;
    
    Cond(i) = 1/(1/C_s1+1/C_c+1/C_s2);
    C_List(i,9) = Cond(i);
        
    
end

Con = sparse(C_List(:,1),C_List(:,2),Cond,N_particles,N_particles);
Con = Con + transpose(Con);

Cona = zeros(N_particles,1);

for i=1:1:N_particles
Cona(i) = sum(Con(i,:));
end

Con = -1*Con;

for i=1:1:N_particles
Con(i,i) = Cona(i);
end

Consave=Con;
% fprintf('Conduction Matrix created\n');

%%
layer_c = 0;

for i = 1:1:N_particles
    if (N(i,direction_cond) <= mean_r)%same temperature
        layer_c = layer_c+1;
    end
end
% layer_c 
layer_bot = layer_c;

layer_c = 0;
for i = 1:1:N_particles
    if ((max(N(:,direction_cond))-N(i,direction_cond)) <= mean_r)%same temperature
        layer_c = layer_c+1;
    end
end
% layer_c ;
layer_top = N_particles - layer_c + 1;

Bot = zeros(N_particles,1);
Top = zeros(N_particles,1);
Vol = zeros(N_particles,1);
Inner_part = zeros(N_particles,1);

%%%Voltage initiation
     for i=1:1:layer_bot
        Bot(i,1) = N(i,8);
        Vol(N(i,8))= Top_temp;
     end
    
    for i= layer_top : 1 : N_particles      
         Top(i,1) = N(i,8);
         Vol(N(i,8))=Bot_temp;   
    end
    

    for i= layer_bot+1:1:layer_top-1
        Inner_part(i,1) = N(i,8);
    end
    
    Top = nonzeros(Top);
    Bot = nonzeros(Bot);
    Inner_part = nonzeros(Inner_part);


Y1 = zeros(size(Con,1),1);

    for inner_p = Inner_part
        for tophere=Top
           Y1(inner_p,1) = Y1(inner_p,1)-Con(inner_p,tophere)*Vol(tophere,1);
        end
        for bothere=Bot
           Y1(inner_p,1) = Y1(inner_p,1)-Con(inner_p,bothere)*Vol(bothere,1);
        end        
    end

Bound_here = [Top;Bot]; 

Con_1 = Con;
Con_1(Bound_here,:)=[];
Con_1(:,Bound_here)=[];
Y1(Bound_here,:)=[];

%%
% fprintf('Solving Started\n');
%Solve for unknown Temperatures
X = Con_1\Y1;
% fprintf('Solved\n');

Vol(Inner_part,1)=X;

I1 = zeros(N_particles,1);
I2 = zeros(N_particles,1);

for tophere = Top
   for j=1:1:N_particles
    I1(tophere,1) =  I1(tophere,1) + Con(tophere,N(j,8))*Vol(N(j,8),1);
   end
end

for bothere = Bot
   for j=1:1:N_particles
    I2(bothere,1) =  I2(bothere,1) + Con(bothere,N(j,8))*Vol(N(j,8),1);
   end
end

Avg_current = (-sum(I1)+sum(I2))/2;

Length_cell =  ScF*(1-Straink);
Area_cell = ScF^2;
Length_keff = mean(N(Top,direction_cond))-mean(N(Bot,direction_cond));
k_eff = -(Avg_current*Length_keff)/(Delta_T*Area_cell);

pf = 0;
for i=1:1:N_particles
pf = pf+(4*pi/3)*(N(i,4)^3);
end

pf=pf/(Length_cell*Area_cell);

% if(file_number==Start)
%     pforgk = pf;
% end

O_CN = 2*N_overlap/N_particles;
G_CN = 2*N_gap/N_particles;
T_CN = 2*N_touch/N_particles;

CN_t = O_CN+G_CN+T_CN;

mean_rc = sum(C_List(:,5))/N_overlap;
[minrc,minrcid] = min(abs(C_List(:,5)-mean_rc));
Loo = C_List(minrcid,12);

Hff = (kBo)*(Tk)/((sqrt(2))*(dm^2)*pi*Pressure*Loo);
K_fo = K_f0/(1+(2*bsbeta*Hff));

Eps = sum(C_List(:,8))/N_gap;
eff_h = (Xi^2)*(r_eff)/(exp(Eps)-1);
[minhe,minheid] = min(abs(C_List(:,7)-eff_h));
Lgg = C_List(minheid,13);
Hff = (kBo)*(Tk)/((sqrt(2))*(dm^2)*pi*Pressure*Lgg);
K_fg = K_f0/(1+(2*bsbeta*Hff));

    alpha = K_s/K_fo;
    beta = mean_rc*alpha/mean_r;        
         
    if beta < 1
      Kc = 0.22*(beta^2); DKg = -0.05*(beta^2);
    else if beta < Bthres
           Kc =  (beta-1)*(2*Bthres/pi-0.22)/(Bthres-1)+0.22 ;DKg =(beta-1)*(-2*log(Bthres)+0.05)/(Bthres-1)-0.05;
        else 
         Kc = 2*(beta)/pi; DKg = -2*log(beta);
        end
    end
        
CC1 = pi*K_fo*mean_r*(Kc+DKg+log(alpha^2));
CC3 = pi*((K_fo+K_fg)/2)*mean_r*(log(alpha^2)+log(1+Xi^2*alpha^2))/2;
CC2 = pi*K_fg*mean_r*Eps; 

Ceff = (O_CN/CN_t)*( 1/(1/C_s1+1/C_s1+1/CC1)) +  ((G_CN)/CN_t)*( 1/(1/C_s1+1/C_s1+1/CC2)) + (T_CN/CN_t)*( 1/(1/C_s1+1/C_s1+1/CC3)) ; 

k_ana = pf*CN_t*(Ceff)/(2*pi*mean_r);
counter_file = counter_file+1;
inipf=(5000*4*pi*(mean_r)^3)/(3*ScF^3);
%%%
Ann_File(counter_file,1) = inipf;
Ann_File(counter_file,2) = Stressk;
Ann_File(counter_file,3) = Straink;
Ann_File(counter_file,4) = requiredRk;
 Ann_File(counter_file,5) = Tc;
Ann_File(counter_file,6) = Pressure;
Ann_File(counter_file,7) = K_s;
Ann_File(counter_file,8) = mg;
Ann_File(counter_file,9) = K_f0;
Ann_File(counter_file,10) = mf;
Ann_File(counter_file,11) = dm;
Ann_File(counter_file,12) = k_eff;
Ann_File(counter_file,13) = k_ana;
Ann_File(counter_file,14) = pf;
Ann_File(counter_file,15) = file_number;
Ann_File(counter_file,16:18) = Stress123;
%%%
File_part(counter_file,1) = Straink;
File_part(counter_file,2) = Stressk;
File_part(counter_file,3) = pf;

File_part(counter_file,4) = CN_t;
File_part(counter_file,5) = O_CN;
File_part(counter_file,6) = G_CN;
File_part(counter_file,7) = T_CN;

File_part(counter_file,8) = mean_rc/mean_r;
File_part(counter_file,9) = Loo/mean_r;
File_part(counter_file,10) = Eps;

File_part(counter_file,11) = eff_h/mean_r;
File_part(counter_file,12) = Lgg/mean_r;
File_part(counter_file,13) = k_eff;
File_part(counter_file,14) = k_ana;
File_part(counter_file,15) = (k_eff-k_ana)*100/(k_eff);

File_part(counter_file,16) = Ceff*1000;
File_part(counter_file,17) = 0;
File_part(counter_file,18) = (O_CN/CN_t)*( 1/(1/C_s1+1/C_s1+1/CC1))*1000;
File_part(counter_file,19) = ((G_CN)/CN_t)*( 1/(1/C_s1+1/C_s1+1/CC2))*1000;
File_part(counter_file,20) = ((T_CN)/CN_t)*( 1/(1/C_s1+1/C_s1+1/CC3))*1000;
File_part(counter_file,21) = file_number;
File_part(counter_file,22:24) = Stress123;

fprintf('K_sim \t K_ana \t Error\n');
fprintf('%0.4f\t%0.4f\t%0.4f\n\n',File_part(counter_file,13:15));


end

end
end
end

inipf=(5000*4*pi*(mean_r)^3)/(3*ScF^3);
Namedat = sprintf('OSi_%0.2f.dat',inipf);
Namemat = sprintf('OSi_%0.2f.mat',inipf);
% save(Namemat,'Ann_File');
save('workspace.m');
dlmwrite(Namedat,File_part,' ');
% A1 = Ann_File(1:16,12);
% A1(:,2) = Ann_File(17:32,12);
% A1(:,3) = (A1(:,1)+A1(:,2))/2
toc;