function[d]=dist(A,B)

%finds distance between two vectors in form A (n,3,n) and B (1,3) 
A2=zeros(size(A,1),3,size(A,3));
B2=zeros(size(B,1),3);
A2(:,1:size(A,2),:)=A;
B2(:,1:size(B,2))=B;
A=A2;
B=B2;
d=sqrt((A(:,1,:)-B(1)).^2 + (A(:,2,:)-B(2)).^2 + (A(:,3,:)-B(3)).^2);