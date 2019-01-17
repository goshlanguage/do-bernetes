clean:
	terraform destroy -auto-approve
	rm -v plan.out terraform.tfstate

deploy:
	terraform plan -out plan.out
	terraform apply "plan.out" -auto-approve
