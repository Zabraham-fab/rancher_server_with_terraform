# rancher_server_with_terraform

## Terraform ile AWS'de Kubernetes Cluster Üzerine Rancher Kurulumu

Günümüzde, bulut tabanlı altyapılar popülerlik kazanmış durumda ve bu altyapılar üzerinde konteyner teknolojileri hızla yaygınlaşıyor. 

I. Adım: AWS Cloud Ortamında EC2 Örneği Oluşturma
   - Terraform kullanarak AWS Cloud ortamında bir EC2 örneği oluşturma adımları.
   - EC2 örneği için gerekli ayarlar ve yapılandırmalar.

II. Adım: Docker ve Kubernetes Kurulumu
   - EC2 örneği üzerinde Docker kurulumu.
   - Kubernetes kurulumu ve yapılandırması.

III. Adım: Rancher Kubernetes Engine ile Küme Oluşturma
   - Rancher Kubernetes Engine'in kullanımı ve kurulum adımları.
   - Kubernetes kümesi oluşturma ve yapılandırma.

IV. Adım: Rancher Kurulumu Helm Chart ile
   - Rancher'ın Helm Chart kullanılarak kurulumu.
   - Rancher'ın yapılandırma ve ayarları.

<img src="1958.png">

Bu küçük çalışmamda, Terraform aracını kullanarak AWS Cloud ortamında bir EC2 örneği oluşturup içine Docker ve Kubernetes kurarak, üzerine Rancher Kubernetes Engine ile bir Kubernetes kümesi oluşturup Helm Chart kullanarak Rancher'ı kurma yapılmıştır.
Bu oluşturduğumuz EC2 örneği, bir target grup içine yerleştirilerek önüne bir yük dengeleyici (load balancer) yerleştirildi. Bu sayede uygulamalarımızın yüksek erişilebilirlik ve ölçeklenebilirlik özelliklerini sağlamış olduk. Ayrıca, Rancher'ı kurarken Helm Chart kullanarak, AWS'de bir alan adına yönlendirilmiş olup bir dış DNS üzerinden erişilebilir hale getirdik. Bu sayede, güvenli bir DNS adı üzerinden Kubernetes kümemizi yönetebilir hale geldik. Tüm bu altyapı, Terraform ile çok hızlı bir şekilde oluşturulabilir ve tek bir komutla yönetilebilir.
Bu adımlar, bir konteyner tabanlı altyapıyı hızlı ve otomatik bir şekilde oluşturmak ve yönetmek için güçlü bir yaklaşım sağladı. Rancher sayesinde, Kubernetes üzerinde çalışan mikroservis uygulamalarımızı ve cluster yönetimini kolaylıkla gerçekleştirebiliriz.
Bu Terraform kodları, AWS Cloud ve Rancher kullanıcıları için değerli bir başlangıç noktası olabilir. Terraform ve Kubernetes gibi araçlar, altyapı otomasyonunda büyük avantajlar sağlar ve hızlı, ölçeklenebilir ve yönetilebilir bir çözüm sunar. Konteyner teknolojilerinin popülerliği ve benimsenmesiyle birlikte, bu tür çözümler giderek daha önemli hale gelmektedir.